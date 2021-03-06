# Style guide CholeskyExperiment

In this project I try to follow the style guide provided by the [official julia documentation](https://docs.julialang.org/en/v1/manual/style-guide/)
However this style guide lets a lot of place for arbitrary choices, I noticed that I work faster with very strict rules which I can follow without to much thinking.
This is why I choose to add some style guide rules for this project.

>> Those rules can vary a lot while this project is still under development


* Always specify the type of the parameters in a method
* When multiple method for one type of process exists put the most specific part of the method name at the end (ex: `getOPFpath_all`, `getOPFpath_one`)
* One empty line between the functions definitions
* Two empty lines after the `module` keyword
* Two empty lines before the `end` keyword ending a module definition
* One empty line between the different part of the importations (`include`, `import`, `using`)
* One empty line between the importation and the first definition of the file
* Follow PEP8 style guide regarding the operators and punctuation, except in type definition and the following operators `::`, `<:` (ex: `myvariable::Union{Int,String} = 1`)
* This project is using module, all code is under a module except the utility files. Therefore include all dependency in the module declaration file.
  I'm not sure that it's a good practice but it makes the imports way easier to follow.
* 120 characters by line (I'm not good at following this rule)
* When a function declaration is too long go the line and keep the first argument on the same line than the `function` keyword. If you have more than two arguments put every argument on a seperated line
