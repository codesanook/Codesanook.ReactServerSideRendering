using Autofac;
using Autofac.Integration.Mvc;
using React;
using React.AutoFacIntegration;
using System.Web.Mvc;

namespace Codesanook.ReactJS.ServerSideRendering.App_Start
{
    public static class AutofacConfig
    {
        public static void RegisterAutofac()
        {
            var builder = new ContainerBuilder();
            // Register your MVC controllers. (MvcApplication is the name of the class in Global.asax.)
            builder.RegisterControllers(typeof(MvcApplication).Assembly);

            // Register React
            builder.RegisterReact();

            // Build the container
            var container = builder.Build();

            ReactSiteConfiguration.Configuration
                .SetLoadBabel(false)
                .AddScriptWithoutTransform("~/Scripts/main.bundle.js");

            // Set the MVC dependency resolver to use Autofac.
            DependencyResolver.SetResolver(new AutofacDependencyResolver(container));
        }
    }
}