## To Run the project

### Restore npm packages and build Node.js project.
- CD to `Codesanook.ReactServerSideRendering`.
- Execute the following commands.
```
yarn install
yarn run dev
```	
### Launch a website
- Set `Codesanook.ReactServerSideRendering` as a main project and `CTRL+F5` to launch a web server.
- You will find a web page with React component in your browser.

## Addtional information
## Required Nuget packages for React server-side rendering  
### For React.AutofacIntegration projet (a class library project)
```
Install-Package React.Core
Install-Package JavaScriptEngineSwitcher.V8
Install-Package JavaScriptEngineSwitcher.V8.Native.win-x86
```

### Codesanook.ReactJS.ServerSideRendering (ASP.NET MVC project)
```
Install-Package React.Core
```

### Other useful tips
- Localhost refused to connect Error in Visual Studio
https://stackoverflow.com/questions/37352603/localhost-refused-to-connect-error-in-visual-studio/48887540
