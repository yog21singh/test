$(function(){
    $.get('/oldQueries',function(result) {
        console.log(result.queries[0].name);
        for(var i=0;i<result.count;i++)
        {   
          $('#tab tr').last().after('<tr><td><input type="text" value="'+result.queries[i].name+'" readonly></td><td><input type="text" value="'+result.queries[i].eMail+'"  readonly></td><td><input type="text" value="'+result.queries[i].phone+'" readonly></td><td><input type="text" value="'+result.queries[i].query+'"  readonly></td><td><input type="text" readonly></td><td><input type="text" readonly></td><td><input type="text" readonly></td></tr>');

        }
    });
    
});
