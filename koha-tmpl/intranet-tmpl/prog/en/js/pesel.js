function ParsePesel(id)
      {
              var s = id;
                  //Sprawdź długość, musi być 11 znaków
                      if ((s.length != 11)){
                          SetError();
                            return;
                      }

                      //Sprawdź, czy wszystkie znaki to cyfry
                      var aInt = new Array();
                      for (i=0;i<11; i++)
                      {
                          aInt[i] = parseInt(s.substring(i,i+1));
                          if (isNaN(aInt[i]))
                          {
                              SetError();
                              //return;
                          }
                      }

                      //Sprawdź sumę kontrolną
                      var wagi = [1,3,7,9,1,3,7,9,1,3,1];
                      var sum=0;
                      for (i=0;i<11;i++)
                          sum+=wagi[i]*aInt[i];
                      if ((sum%10)!=0){
                          SetError();
                       //   return;
                      }

                      //Policz rok z uwzględnieniem XIX, XXI, XXII i XXIII wieku
                      var year = 1900+aInt[0]*10+aInt[1];
                      if (aInt[2]>=2 && aInt[2]<8)
                          year+=Math.floor(aInt[2]/2)*100;
                      if (aInt[2]>=8)
                          year-=100;

                      var month = (aInt[2]%2)*10+aInt[3];
                      var day = aInt[4]*10+aInt[5];

                      var sex = (aInt[9]%2==1)?"M":"K";

                      return day + "\/" + month + "\/" + year;

      }
function SetError(){
    alert("Błędny PESEL. Sprawdź datę urodzenia.");
    return;
}
