using Autofac;
using JavaScriptEngineSwitcher.Core;
using JavaScriptEngineSwitcher.V8;
using React.AutofacIntegration;
using System;
using System.Globalization;
using System.Reflection;
using System.Web;

namespace React.AutoFacIntegration
{
    public static class ReactConfig
    {
        public static void RegisterReact(this ContainerBuilder builder)
        {
            JsEngineSwitcher.Current.DefaultEngineName = V8JsEngine.EngineName;
            JsEngineSwitcher.Current.EngineFactories.AddV8();

            // From React.NET\src\React.Core\AssemblyRegistration.cs
            /*
			container.Register<IReactSiteConfiguration>((c, o) => ReactSiteConfiguration.Configuration);
			container.Register<IFileCacheHash, FileCacheHash>().AsPerRequestSingleton();
			container.Register<IJsEngineSwitcher>((c, o) => JsEngineSwitcher.Current);

			container.Register<IJavaScriptEngineFactory, JavaScriptEngineFactory>().AsSingleton();
			container.Register<IReactIdGenerator, ReactIdGenerator>().AsSingleton();
			container.Register<IReactEnvironment, ReactEnvironment>().AsPerRequestSingleton();
           */ 

            builder.RegisterInstance(ReactSiteConfiguration.Configuration).As<IReactSiteConfiguration>().SingleInstance();
            builder.RegisterType<FileCacheHash>().As<IFileCacheHash>().InstancePerDependency();

            builder.RegisterInstance(JsEngineSwitcher.Current).As<IJsEngineSwitcher>().SingleInstance();

            /*
            JavaScriptEngineFactory(
                IJsEngineSwitcher jsEngineSwitcher,
                IReactSiteConfiguration config,
                ICache cache,
                IFileSystem fileSystem
            )
            */
            builder.RegisterType<JavaScriptEngineFactory>().As<IJavaScriptEngineFactory>().SingleInstance();
            builder.RegisterType<ReactIdGenerator>().As<IReactIdGenerator>().SingleInstance();
            builder.RegisterType<ReactEnvironment>().As<IReactEnvironment>().InstancePerRequest();

            // ICache used by JavaScriptEngineFactory and ReactEnvironment
            // React.NET\src\React.Web\AssemblyRegistration.cs
            // container.Register<ICache, AspNetCache>().AsPerRequestSingleton();
            builder.Register(c => new AspNetCache(HttpRuntime.Cache)).As<ICache>().InstancePerDependency();

            // IFileSystem used by JavaScriptEngineFactory and ReactEnvironment
            // React.NET\src\React.Web\AssemblyRegistration.cs
            // container.Register<IFileSystem, AspNetFileSystem>().AsPerRequestSingleton();
            builder.RegisterType<AspNetFileSystem>().As<IFileSystem>().InstancePerDependency();

            /*
            public ReactEnvironment(
                IJavaScriptEngineFactory engineFactory,
                IReactSiteConfiguration config,
                ICache cache,
                IFileSystem fileSystem,
                IFileCacheHash fileCacheHash,
                IReactIdGenerator reactIdGenerator
                );
            */
            RedirectAssembly(
                "JavaScriptEngineSwitcher.Core",
                new Version("3.1.0.0"),
                "c608b2a8cc9e4472"
            );
        }

        private static void RedirectAssembly(string shortName, Version targetVersion, string publicKeyToken)
        {
            ResolveEventHandler handler = null;
            handler = (sender, args) => {

                // Use latest strong name & version when trying to load SDK assemblies
                var requestedAssembly = new AssemblyName(args.Name);
                if (requestedAssembly.Name != shortName)
                    return null;

                requestedAssembly.Version = targetVersion;
                requestedAssembly.CultureInfo = CultureInfo.InvariantCulture;
                //For security reasons public key token should match;
                requestedAssembly.SetPublicKeyToken(new AssemblyName("x, PublicKeyToken=" + publicKeyToken).GetPublicKeyToken());
                AppDomain.CurrentDomain.AssemblyResolve -= handler;

                return Assembly.Load(requestedAssembly);
            };

            AppDomain.CurrentDomain.AssemblyResolve += handler;
        }
    }
}
