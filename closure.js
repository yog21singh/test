var globalVar = 10;
var makeFoo = function(offset) {
    return function() {
        console.log(offset + 10);
    }
}
var foo = makeFoo(globalVar);
globalVar = 20;
foo();

