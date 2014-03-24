package C4::HoldsQueue;

# Copyright 2011 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# FIXME: expand perldoc, explain intended logic

use strict;
use warnings;

use C4::Context;
use C4::Search;
use C4::Items;
use C4::Branch;
use C4::Circulation;
use C4::Members;
use C4::Biblio;
use C4::Dates qw/format_date/;

use List::Util qw(shuffle);
use List::MoreUtils qw(any);
use Data::Dumper;
use File::Pid;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
BEGIN {
    $VERSION = 3.03;
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        &CreateQueue
        &GetHoldsQueueItems

        &TransportCostMatrix
        &UpdateTransportCostMatrix

        &MarkHoldPrinted
        &GetItemNumberFromTmpHold
        &GetTmpHoldInfo
     );
}


=head1 FUNCTIONS

=head2 TransportCostMatrix

  TransportCostMatrix();

Returns Transport Cost Matrix as a hashref <to branch code> => <from branch code> => cost

=cut

sub TransportCostMatrix {
    my $dbh   = C4::Context->dbh;
    my $transport_costs = $dbh->selectall_arrayref("SELECT * FROM transport_cost",{ Slice => {} });

    my %transport_cost_matrix;
    foreach (@$transport_costs) {
        my $from = $_->{frombranch};
        my $to = $_->{tobranch};
        my $cost = $_->{cost};
        my $disabled = $_->{disable_transfer};
        $transport_cost_matrix{$to}{$from} = { cost => $cost, disable_transfer => $disabled };
    }
    return \%transport_cost_matrix;
}

=head2 UpdateTransportCostMatrix

  UpdateTransportCostMatrix($records);

Updates full Transport Cost Matrix table. $records is an arrayref of records.
Records: { frombranch => <code>, tobranch => <code>, cost => <figure>, disable_transfer => <0,1> }

=cut

sub UpdateTransportCostMatrix {
    my ($records) = @_;
    my $dbh   = C4::Context->dbh;

    my $sth = $dbh->prepare("INSERT INTO transport_cost (frombranch, tobranch, cost, disable_transfer) VALUES (?, ?, ?, ?)");

    $dbh->do("TRUNCATE TABLE transport_cost");
    foreach (@$records) {
        my $cost = $_->{cost};
        my $from = $_->{frombranch};
        my $to = $_->{tobranch};
        if ($_->{disable_transfer}) {
            $cost ||= 0;
        }
        elsif ( !defined ($cost) || ($cost !~ m/(0|[1-9][0-9]*)(\.[0-9]*)?/o) ) {
            warn  "Invalid $from -> $to cost $cost - must be a number >= 0, disablig";
            $cost = 0;
            $_->{disable_transfer} = 1;
        }
        $sth->execute( $from, $to, $cost, $_->{disable_transfer} ? 1 : 0 );
    }
}

=head2 GetHoldsQueueItems

  GetHoldsQueueItems($branch);

Returns hold queue for a holding branch. If branch is omitted, then whole queue is returned

=cut

sub GetHoldsQueueItems {
    my ($branchlimit, $printstatus) = @_;
    my $dbh   = C4::Context->dbh;

    my @bind_params = ();
    my $query = q/SELECT tmp_holdsqueue.*, biblio.author, items.ccode, items.itype, biblioitems.itemtype, items.location, items.enumchron, items.cn_sort, biblioitems.publishercode,biblio.copyrightdate,biblioitems.publicationyear,biblioitems.pages,biblioitems.size,biblioitems.publicationyear,biblioitems.isbn,items.copynumber
                  FROM tmp_holdsqueue
                       JOIN biblio      USING (biblionumber)
                  LEFT JOIN biblioitems USING (biblionumber)
                  LEFT JOIN items       USING (  itemnumber)
                /;
    if ($branchlimit) {
        $query .=" WHERE tmp_holdsqueue.holdingbranch = ?";
        push @bind_params, $branchlimit;
    }
    if (C4::Context->preference('printSlipFromHoldsQueue')){
        $query .= $branchlimit ? " AND" : " WHERE";
        $query .= " tmp_holdsqueue.print_status = ?";
        push @bind_params, $printstatus;
    }
    $query .= " ORDER BY ccode, location, cn_sort, author, title, pickbranch, reservedate";
    my $sth = $dbh->prepare($query);
    $sth->execute(@bind_params);
    my $items = [];
    while ( my $row = $sth->fetchrow_hashref ){
        my $record = GetMarcBiblio($row->{biblionumber});
        if ($record){
            $row->{subtitle} = GetRecordValue('subtitle',$record,'')->[0]->{subfield};
            $row->{parts} = GetRecordValue('parts',$record,'')->[0]->{subfield};
            $row->{numbers} = GetRecordValue('numbers',$record,'')->[0]->{subfield};
        }

        # return the bib-level or item-level itype per syspref
        if (!C4::Context->preference('item-level_itypes')) {
            $row->{itype} = $row->{itemtype};
        }
        delete $row->{itemtype};

        push @$items, $row;
    }
    return $items;
}

=head2 CreateQueue

  CreateQueue();

Top level function that turns reserves into tmp_holdsqueue and hold_fill_targets.

=cut

sub CreateQueue {
    my ($waitforlock) = @_;

    #avoid runnig script when already running
    my $pidfile = File::Pid->new({
        file => '/var/lock/build_holdsqueue.pid',
        });
    while ( my $num = $pidfile->running ) {
        $waitforlock || return();
        sleep(1);
    }
    $pidfile->write;

    my $dbh   = C4::Context->dbh;
    $dbh->begin_work;

    $dbh->do("DELETE FROM tmp_holdsqueue");  # clear the old table for new info
    $dbh->do("DELETE FROM hold_fill_targets");

    my $total_bibs            = 0;
    my $total_requests        = 0;
    my $total_available_items = 0;
    my $num_items_mapped      = 0;

    my $branches_to_use;
    my $transport_cost_matrix;
    my $use_transport_cost_matrix = C4::Context->preference("UseTransportCostMatrix");
    if ($use_transport_cost_matrix) {
        $transport_cost_matrix = TransportCostMatrix();
        unless (keys %$transport_cost_matrix) {
            warn "UseTransportCostMatrix set to yes, but matrix not populated";
            undef $transport_cost_matrix;
        }
    }
    unless ($transport_cost_matrix) {
        $branches_to_use = load_branches_to_pull_from();
    }

    my $bibs_with_pending_requests = GetBibsWithPendingHoldRequests();

    foreach my $biblionumber (@$bibs_with_pending_requests) {
        $total_bibs++;
        my $hold_requests   = GetPendingHoldRequestsForBib($biblionumber);
        my $available_items = GetItemsAvailableToFillHoldRequestsForBib($biblionumber, $branches_to_use);
        $total_requests        += scalar(@$hold_requests);
        $total_available_items += scalar(@$available_items);

        my $item_map = MapItemsToHoldRequestsByLocation($hold_requests, $available_items, $branches_to_use, $transport_cost_matrix);
        $item_map  or next;
        my $item_map_size = scalar(keys %$item_map)
          or next;

        $num_items_mapped += $item_map_size;
        CreatePicklistFromItemMap($item_map);
        AddToHoldTargetMap($item_map);
        AddItemnumberToReserves($item_map);
        if (($item_map_size < scalar(@$hold_requests  )) and
            ($item_map_size < scalar(@$available_items))) {
            # DOUBLE CHECK, but this is probably OK - unfilled item-level requests
            # FIXME
            #warn "unfilled requests for $biblionumber";
            #warn Dumper($hold_requests), Dumper($available_items), Dumper($item_map);
        }
    }
    $dbh->commit;
    $pidfile->remove();
}

=head2 GetBibsWithPendingHoldRequests

  my $biblionumber_aref = GetBibsWithPendingHoldRequests();

Return an arrayref of the biblionumbers of all bibs
that have one or more unfilled hold requests.

=cut

sub GetBibsWithPendingHoldRequests {
    my $dbh = C4::Context->dbh;

    my $bib_query = "SELECT DISTINCT biblionumber
                     FROM reserves
                     WHERE found IS NULL
                     AND priority > 0
                     AND reservedate <= CURRENT_DATE()
                     AND suspend = 0
                     ";
    my $sth = $dbh->prepare($bib_query);

    $sth->execute();
    my $biblionumbers = $sth->fetchall_arrayref();

    return [ map { $_->[0] } @$biblionumbers ];
}

=head2 GetPendingHoldRequestsForBib

  my $requests = GetPendingHoldRequestsForBib($biblionumber);

Returns an arrayref of hashrefs to pending, unfilled hold requests
on the bib identified by $biblionumber.  The following keys
are present in each hashref:

    biblionumber
    borrowernumber
    itemnumber
    priority
    branchcode
    reservedate
    reservenotes
    borrowerbranch
    pickup_location

The arrayref is sorted in order of increasing priority.

=cut

sub GetPendingHoldRequestsForBib {
    my $biblionumber = shift;

    my $dbh = C4::Context->dbh;

    my $request_query = "SELECT reserve_id, biblionumber, borrowernumber, itemnumber, priority, reserves.branchcode,
                                reservedate, reservenotes, borrowers.branchcode AS borrowerbranch, pickup_location, print_status,timestamp
                         FROM reserves
                         JOIN borrowers USING (borrowernumber)
                         WHERE biblionumber = ?
                         AND found IS NULL
                         AND priority > 0
                         AND reservedate <= CURRENT_DATE()
                         AND suspend = 0
                         ORDER BY priority";
    my $sth = $dbh->prepare($request_query);
    $sth->execute($biblionumber);

    my $requests = $sth->fetchall_arrayref({});
    return $requests;

}

=head2 GetItemsAvailableToFillHoldRequestsForBib

  my $available_items = GetItemsAvailableToFillHoldRequestsForBib($biblionumber, $branches_ar);

Returns an arrayref of items available to fill hold requests
for the bib identified by C<$biblionumber>.  An item is available
to fill a hold request if and only if:

    * it is not on loan
    * it is not withdrawn
    * it is not marked notforloan
    * it is not currently in transit
    * it is not lost
    * it is not sitting on the hold shelf
    * it is not damaged (unless AllowHoldsOnDamagedItems is on)

=cut

sub GetItemsAvailableToFillHoldRequestsForBib {
    my ($biblionumber, $branches_to_use) = @_;

    my $dbh = C4::Context->dbh;
    my $items_query = "SELECT itemnumber, homebranch, holdingbranch, itemtypes.itemtype AS itype
                       FROM items ";

    if (C4::Context->preference('item-level_itypes')) {
        $items_query .=   "LEFT JOIN itemtypes ON (itemtypes.itemtype = items.itype) ";
    } else {
        $items_query .=   "JOIN biblioitems USING (biblioitemnumber)
                           LEFT JOIN itemtypes USING (itemtype) ";
    }
    $items_query .=   "WHERE items.notforloan = 0
                       AND holdingbranch IS NOT NULL
                       AND itemlost = 0
                       AND withdrawn = 0";
    $items_query .= "  AND damaged = 0" unless C4::Context->preference('AllowHoldsOnDamagedItems');
    $items_query .= "  AND items.onloan IS NULL
                       AND (itemtypes.notforloan IS NULL OR itemtypes.notforloan = 0)
                       AND itemnumber NOT IN (
                           SELECT itemnumber
                           FROM reserves
                           WHERE biblionumber = ?
                           AND itemnumber IS NOT NULL
                           AND (found IS NOT NULL OR priority = 0)
                        )
                       AND items.biblionumber = ?";

    my @params = ($biblionumber, $biblionumber);
    if ($branches_to_use && @$branches_to_use) {
        $items_query .= " AND holdingbranch IN (" . join (",", map { "?" } @$branches_to_use) . ")";
        push @params, @$branches_to_use;
    }
    my $sth = $dbh->prepare($items_query);
    $sth->execute(@params);

    my $itm = $sth->fetchall_arrayref({});
    my @items = grep { ! scalar GetTransfers($_->{itemnumber}) } @$itm;
    return [ grep {
        my $rule = GetBranchItemRule($_->{homebranch}, $_->{itype});
        $_->{holdallowed} = $rule->{holdallowed};
    } @items ];
}

=head2 MapItemsToHoldRequests

  MapItemsToHoldRequests($hold_requests, $available_items, $branches, $transport_cost_matrix)

=cut

sub MapItemsToHoldRequests {
    my ($hold_requests, $available_items, $branches_to_use, $transport_cost_matrix) = @_;

    # handle trival cases
    return unless scalar(@$hold_requests) > 0;
    return unless scalar(@$available_items) > 0;

    # identify item-level requests
    my %specific_items_requested = map { $_->{itemnumber} => 1 }
                                   grep { defined($_->{itemnumber}) }
                                   @$hold_requests;

    # group available items by itemnumber
    my %items_by_itemnumber = map { $_->{itemnumber} => $_ } @$available_items;

    # items already allocated
    my %allocated_items = ();

    # map of items to hold requests
    my %item_map = ();

    # figure out which item-level requests can be filled
    my $num_items_remaining = scalar(@$available_items);
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining == 0;

        # is this an item-level request?
        if (defined($request->{itemnumber})) {
            # fill it if possible; if not skip it
            if (exists $items_by_itemnumber{$request->{itemnumber}} and
                not exists $allocated_items{$request->{itemnumber}}) {
                $item_map{$request->{itemnumber}} = {
                    reserve_id => $request->{reserve_id},
                    borrowernumber => $request->{borrowernumber},
                    biblionumber => $request->{biblionumber},
                    holdingbranch =>  $items_by_itemnumber{$request->{itemnumber}}->{holdingbranch},
                    pickup_branch => $request->{branchcode} || $request->{borrowerbranch},
                    item_level => 1,
                    reservedate => $request->{reservedate},
                    reservenotes => $request->{reservenotes},
                    pickup_location => $request->{pickup_location},
                    print_status => $request->{print_status},
                };
                $allocated_items{$request->{itemnumber}}++;
                $num_items_remaining--;
            }
        } else {
            # it's title-level request that will take up one item
            $num_items_remaining--;
        }
    }

    # group available items by branch
    my %items_by_branch = ();
    foreach my $item (@$available_items) {
        next unless $item->{holdallowed};

        push @{ $items_by_branch{ $item->{holdingbranch} } }, $item
          unless exists $allocated_items{ $item->{itemnumber} };
    }
    return \%item_map unless keys %items_by_branch;

    # now handle the title-level requests
    $num_items_remaining = scalar(@$available_items) - scalar(keys %allocated_items);
    my $pull_branches;
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining == 0;
        next if defined($request->{itemnumber}); # already handled these

        # look for local match first
        my $pickup_branch = $request->{branchcode} || $request->{borrowerbranch};
        my ($itemnumber, $holdingbranch);

        my $holding_branch_items = $items_by_branch{$pickup_branch};
        if ( $holding_branch_items ) {
            foreach my $item (@$holding_branch_items) {
                if ( $request->{borrowerbranch} eq $item->{homebranch} ) {
                    $itemnumber = $item->{itemnumber};
                    last;
                }
            }
            $holdingbranch = $pickup_branch;
        }
        elsif ($transport_cost_matrix) {
            $pull_branches = [keys %items_by_branch];
            $holdingbranch = least_cost_branch( $pickup_branch, $pull_branches, $transport_cost_matrix );
            if ( $holdingbranch ) {

                my $holding_branch_items = $items_by_branch{$holdingbranch};
                foreach my $item (@$holding_branch_items) {
                    next if $request->{borrowerbranch} ne $item->{homebranch};

                    $itemnumber = $item->{itemnumber};
                    last;
                }
            }
            else {
                warn "No transport costs for $pickup_branch";
            }
        }

        unless ($itemnumber) {
            # not found yet, fall back to basics
            if ($branches_to_use) {
                $pull_branches = $branches_to_use;
            } else {
                $pull_branches = [keys %items_by_branch];
            }
            PULL_BRANCHES:
            foreach my $branch (@$pull_branches) {
                my $holding_branch_items = $items_by_branch{$branch}
                  or next;

                $holdingbranch ||= $branch;
                foreach my $item (@$holding_branch_items) {
                    next if $pickup_branch ne $item->{homebranch};
                    next if ( $item->{holdallowed} == 1 && $item->{homebranch} ne $request->{borrowerbranch} );

                    $itemnumber = $item->{itemnumber};
                    $holdingbranch = $branch;
                    last PULL_BRANCHES;
                }
            }

            unless ( $itemnumber ) {
                foreach my $current_item ( @{ $items_by_branch{$holdingbranch} } ) {
                    if ( $holdingbranch && ( $current_item->{holdallowed} == 2 || $request->{borrowerbranch} eq $current_item->{homebranch} ) ) {
                        $itemnumber = $current_item->{itemnumber};
                        last; # quit this loop as soon as we have a suitable item
                    }
                }
            }
        }

        if ($itemnumber) {
            my $holding_branch_items = $items_by_branch{$holdingbranch}
              or die "Have $itemnumber, $holdingbranch, but no items!";
            @$holding_branch_items = grep { $_->{itemnumber} != $itemnumber } @$holding_branch_items;
            delete $items_by_branch{$holdingbranch} unless @$holding_branch_items;

            $item_map{$itemnumber} = {
                reserve_id => $request->{reserve_id},
                borrowernumber => $request->{borrowernumber},
                biblionumber => $request->{biblionumber},
                holdingbranch => $holdingbranch,
                pickup_branch => $pickup_branch,
                item_level => 0,
                reservedate => $request->{reservedate},
                reservenotes => $request->{reservenotes},
                pickup_location => $request->{pickup_location},
                print_status => $request->{print_status},
            };
            $num_items_remaining--;
        }
    }
    return \%item_map;
}

=head2 CreatePickListFromItemMap

=cut

sub CreatePicklistFromItemMap {
    my $item_map = shift;

    my $dbh = C4::Context->dbh;

    my $sth_load=$dbh->prepare("
        INSERT INTO tmp_holdsqueue (reserve_id,biblionumber,itemnumber,barcode,surname,firstname,phone,borrowernumber,
                                    cardnumber,reservedate,title, itemcallnumber,
                                    holdingbranch,pickbranch,notes, item_level_request,print_status, pickup_location, date_time)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
    ");

    foreach my $itemnumber  (sort keys %$item_map) {
        my $mapped_item = $item_map->{$itemnumber};
        my $reserve_id = $mapped_item->{reserve_id};
        my $biblionumber = $mapped_item->{biblionumber};
        my $borrowernumber = $mapped_item->{borrowernumber};
        my $pickbranch = $mapped_item->{pickup_branch};
        my $holdingbranch = $mapped_item->{holdingbranch};
        my $reservedate = $mapped_item->{reservedate};
        my $reservenotes = $mapped_item->{reservenotes};
        my $item_level = $mapped_item->{item_level};
        my $pickup_location = $mapped_item->{pickup_location};
        my $print_status = $mapped_item->{print_status};
        my $date_time = $mapped_item->{date_time};

        my $item = GetItem($itemnumber);
        my $barcode = $item->{barcode};
        my $itemcallnumber = $item->{itemcallnumber};

        my $borrower = GetMember('borrowernumber'=>$borrowernumber);
        my $cardnumber = $borrower->{'cardnumber'};
        my $surname = $borrower->{'surname'};
        my $firstname = $borrower->{'firstname'};
        my $phone = $borrower->{'phone'};

        my $bib = GetBiblioData($biblionumber);
        my $title = $bib->{title};

        $sth_load->execute($reserve_id,$biblionumber, $itemnumber, $barcode, $surname, $firstname, $phone, $borrowernumber,
                           $cardnumber, $reservedate, $title, $itemcallnumber,
                           $holdingbranch, $pickbranch, $reservenotes, $item_level,$print_status, $pickup_location, $date_time);
    }
}

=head2 AddToHoldTargetMap

=cut

sub AddToHoldTargetMap {
    my $item_map = shift;

    my $dbh = C4::Context->dbh;

    my $insert_sql = q(
        INSERT INTO hold_fill_targets (borrowernumber, biblionumber, itemnumber, source_branchcode, item_level_request)
                               VALUES (?, ?, ?, ?, ?)
    );
    my $sth_insert = $dbh->prepare($insert_sql);

    foreach my $itemnumber (keys %$item_map) {
        my $mapped_item = $item_map->{$itemnumber};
        $sth_insert->execute($mapped_item->{borrowernumber}, $mapped_item->{biblionumber}, $itemnumber,
                             $mapped_item->{holdingbranch}, $mapped_item->{item_level});
    }
}

# Helper functions, not part of any interface

sub _trim {
    return $_[0] unless $_[0];
    $_[0] =~ s/^\s+//;
    $_[0] =~ s/\s+$//;
    $_[0];
}

sub load_branches_to_pull_from {
    my $static_branch_list = C4::Context->preference("StaticHoldsQueueWeight")
      or return;

    my @branches_to_use = map _trim($_), split /,/, $static_branch_list;

    @branches_to_use = shuffle(@branches_to_use) if  C4::Context->preference("RandomizeHoldsQueueWeight");

    return \@branches_to_use;
}

sub least_cost_branch {

    #$from - arrayref
    my ($to, $from, $transport_cost_matrix) = @_;

    # Nothing really spectacular: supply to branch, a list of potential from branches
    # and find the minimum from - to value from the transport_cost_matrix
    return $from->[0] if @$from == 1;

    # If the pickup library is in the list of libraries to pull from,
    # return that library right away, it is obviously the least costly
    return ($to) if any { $_ eq $to } @$from;

    my ($least_cost, @branch);
    foreach (@$from) {
        my $cell = $transport_cost_matrix->{$to}{$_};
        next if $cell->{disable_transfer};

        my $cost = $cell->{cost};
        next unless defined $cost; # XXX should this be reported?

        unless (defined $least_cost) {
            $least_cost = $cost;
            push @branch, $_;
            next;
        }

        next if $cost > $least_cost;

        if ($cost == $least_cost) {
            push @branch, $_;
            next;
        }

        @branch = ($_);
        $least_cost = $cost;
    }

    return $branch[0];

    # XXX return a random @branch with minimum cost instead of the first one;
    # return $branch[0] if @branch == 1;
}
=head2 MarkHoldPrinted
    MarkHoldPrinted($reserve_id)
    Change print status as printed.
=cut

sub MarkHoldPrinted {
   my ( $reserve_id ) = @_;
   my $dbh = C4::Context->dbh;
   my $strsth="UPDATE reserves INNER JOIN tmp_holdsqueue USING (reserve_id)
                SET reserves.print_status = 1 , tmp_holdsqueue.print_status = 1
                WHERE reserve_id = ?
		";
    my $sth = $dbh->prepare($strsth);
	$sth->execute($reserve_id);

    return 1;
}

=head2 MapItemsToHoldRequestsByLocation

  MapItemsToHoldRequestsByLocation($hold_requests, $available_items, $branches, $transport_cost_matrix)

=cut

sub MapItemsToHoldRequestsByLocation {
    my ($hold_requests, $available_items, $branches_to_use, $transport_cost_matrix) = @_;

    # handle trival cases
    return unless scalar(@$hold_requests) > 0;
    return unless scalar(@$available_items) > 0;

    # identify item-level requests
    my %specific_items_requested = map { $_->{itemnumber} => 1 }
                                   grep { defined($_->{itemnumber}) }
                                   @$hold_requests;

    # group available items by itemnumber
    my %items_by_itemnumber = map { $_->{itemnumber} => $_ } @$available_items;

    my $items_by_location = GetAvailableItemsByLocation([keys %items_by_itemnumber]);

    # items already allocated
    my %allocated_items = ();

    # map of items to hold requests
    my %item_map = ();

    # figure out which item-level requests can be filled
    my $num_items_remaining = scalar(@$available_items);
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining == 0;

        # is this an item-level request?
        if (defined($request->{itemnumber})) {
            # fill it if possible; if not skip it
            if (exists $items_by_itemnumber{$request->{itemnumber}} and
                not exists $allocated_items{$request->{itemnumber}}) {
                $item_map{$request->{itemnumber}} = {
                    reserve_id => $request->{reserve_id},
                    borrowernumber => $request->{borrowernumber},
                    biblionumber => $request->{biblionumber},
                    holdingbranch =>  $items_by_itemnumber{$request->{itemnumber}}->{holdingbranch},
                    pickup_branch => $request->{branchcode} || $request->{borrowerbranch},
                    item_level => 1,
                    reservedate => $request->{reservedate},
                    reservenotes => $request->{reservenotes},
                    pickup_location => $request->{pickup_location},
                    print_status => $request->{print_status},
                    date_time => $request->{timestamp},
                };
                $allocated_items{$request->{itemnumber}}++;
                $num_items_remaining--;
            }
        } else {
            # it's title-level request that will take up one item
            ## $num_items_remaining--;
        }
    }
    # group available items by itemnumber
    my %items_by_branch = ();
    foreach my $item (@$available_items) {
        next unless $item->{holdallowed};

        foreach my $loc ( keys %{$items_by_location} ) {
            if ((not exists $allocated_items{ $item->{itemnumber}}) &&
                (grep { $_->{itemnumber} == $item->{itemnumber} } @{$items_by_location->{$loc}})) {
                push @{$items_by_branch{$item->{holdingbranch}}{$loc}}, $item;
            }
        }
    }
    return \%item_map unless keys %items_by_branch;

    # now handle the title-level requests
    $num_items_remaining = scalar(@$available_items) - scalar(keys %allocated_items);
    my %num_items_remaining_by_loc;
    foreach my $branch ( keys %items_by_branch ) {
        my $items = $items_by_branch{$branch};
        foreach (keys %$items){
           $num_items_remaining_by_loc{$branch}{$_} = scalar @{$items_by_branch{$branch}{$_}};
        }
    }
    my $pull_branches;
    foreach my $request (@$hold_requests) {
        last if $num_items_remaining == 0;
        next if defined($request->{itemnumber}); # already handled these

        #select available pickup location
        my $pickup_location = $request->{'pickup_location'};
        #pickup branch
        my $pickup_branch = $request->{branchcode};

        my @avail_location;
        if ( defined $num_items_remaining_by_loc{$pickup_branch}{$pickup_location} &&
                $num_items_remaining_by_loc{$pickup_branch}{$pickup_location} > 0 ) {
            @avail_location = ( $pickup_location );
        } else {
            @avail_location = grep { /${pickup_location}/ } keys $num_items_remaining_by_loc{$pickup_branch};
        }
        #next when no items with this location available
        next if scalar @avail_location < 1;

        # look for local match first
        my ($itemnumber, $holdingbranch);

        #get first location which have avail items
        #and get that item
        my $selected_loc;
        foreach my $loc (@avail_location) {
            if ( $num_items_remaining_by_loc{$pickup_branch}{$loc} > 0 ) {
                $selected_loc = $loc;
                foreach my $item ( @{$items_by_branch{$pickup_branch}{$loc}} ) {
                    unless ( exists $allocated_items{$item->{'itemnumber'}} ) {
                        $itemnumber = $item->{'itemnumber'};
                        $allocated_items{$itemnumber}++;
                        $holdingbranch = $item->{holdingbranch};
                        last;
                    }
                }
                last;
            }
        }
        if ($itemnumber) {
            my $holding_branch_items = $items_by_branch{$pickup_branch}{$selected_loc}
              or die "Have $itemnumber, $holdingbranch, but no items!";
            @$holding_branch_items = grep { $_->{itemnumber} != $itemnumber } @$holding_branch_items;
            delete $items_by_branch{$pickup_branch}{$selected_loc} unless @$holding_branch_items;

            $item_map{$itemnumber} = {
                reserve_id => $request->{reserve_id},
                borrowernumber => $request->{borrowernumber},
                biblionumber => $request->{biblionumber},
                holdingbranch => $holdingbranch,
                pickup_branch => $pickup_branch,
                item_level => 0,
                reservedate => $request->{reservedate},
                reservenotes => $request->{reservenotes},
                pickup_location => $request->{pickup_location},
                print_status => $request->{print_status},
                date_time => $request->{timestamp},
            };
            $num_items_remaining--;
            $num_items_remaining_by_loc{$pickup_branch}{$selected_loc}--;
        }
    }
    return \%item_map;
}

=head2 GetItemNumberFromTmpHold
    $itemnumber = GetItemNumberFromTmpHold($reserve_id)
    Returns itemnumber associated with hold.
    Item number is taken from tmp_holdsqueue table, which is
    populated by bulid_holds_queue.pl script.

=cut
sub	GetItemNumberFromTmpHold{
	my ( $reserve_id ) = @_;
	my $dbh = C4::Context->dbh;
	my $strsth="SELECT itemnumber
                  FROM tmp_holdsqueue
                WHERE reserve_id = ?
		";
	my $sth = $dbh->prepare($strsth);
	$sth->execute($reserve_id);

	my $data = $sth->fetchrow;
	return $data;
}

sub GetTmpHoldInfo {
    my ( $reserve_id ) = @_;
    my $dbh = C4::Context->dbh;
    my $strsth = "SELECT * FROM tmp_holdsqueue
                    WHERE reserve_id = ?
                ";
    my $sth = $dbh->prepare($strsth);
	$sth->execute($reserve_id);
    my $data = $sth->fetchrow_hashref;
    return $data;
}
=head2 AddItemnumberToReserves

=cut

sub AddItemnumberToReserves {
    my $item_map = shift;
    my $dbh = C4::Context->dbh;

    my $sth_load=$dbh->prepare("UPDATE reserves SET itemnumber=? WHERE reserve_id=?");

    foreach my $itemnumber (sort keys %$item_map) {
        my $mapped_item = $item_map->{$itemnumber};
        my $reserve_id = $mapped_item->{reserve_id};

        $sth_load->execute($itemnumber, $reserve_id);
    }
}

1;
