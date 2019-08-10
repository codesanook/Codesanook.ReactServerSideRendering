using Autofac;
using Autofac.Integration.Mvc;
using React.AutoFacIntegration;
using System.Web.Mvc;

namespace Codesanook.ReactJS.ServerSideRendering.App_Start
{
    public class AutofacConfig
    {
        public static void RegisterAutofac()
        {
            var builder = new ContainerBuilder();

            // Register your MVC controllers. (MvcApplication is the name of
            // the class in Global.asax.)
            builder.RegisterControllers(typeof(MvcApplication).Assembly);

            //Register React
            builder.RegisterReact();

            // Set the dependency resolver to be Autofac.
            var container = builder.Build();
            DependencyResolver.SetResolver(new AutofacDependencyResolver(container));
        }
    }
}