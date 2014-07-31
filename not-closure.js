var globalVar = 10;
var foo = function() {
    console.log(globalVar + 10);
}
globalVar = 20;
foo();

