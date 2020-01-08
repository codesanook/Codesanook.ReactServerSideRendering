 Get-Command node -ErrorAction Ignore | Out-Null
 if(-not $?){
    throw "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."
 }