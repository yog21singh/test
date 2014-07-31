/* Javascript */
var te=0;
var  fin1,fin2,count,usercnt=0;

var pos=new Array;
$(function(){
    $('form#query').submit(function(event) {
    event.preventDefault();
    $.post('/query', $('form#query').serialize(), function(data) {
        console.log("Returned from server side");
    //$('div#thankyou-note').show();
    $('form#contact').find('input[type=text], textarea').val('');
	console.log('###');
	console.log(data);
  });
});
});
    
     /* $('#submit').on('click', function() {
            var form={"name":$("#name").val(),"mail":$("#eMail").val(),"phone":$("#phone").val(),"query":$("#query").val()};
          //  var valid=validation();  
         //   console.log("val="+valid);
            alert(form.name);
            $.get('/submitQuery', { form : form },function(result) {
                console.log("result="+result);
            });
    });
    
    
    function validation()
    {
        if (form[0]=="")
        {
            
            $("#nameError").show();
            return false;
        }
        else if(form[1]=="")
        {
             $("#emailError").show();
            return false;
        }
        else if(form[2]=="")
        {
            $("#phoneError").show();
            return false;
        }
        else if(form[3]=="")
        {
            $("#queryError").show();
            return false;
        }
        else 
            return true;
    }*/

    
    
    
    
    
   