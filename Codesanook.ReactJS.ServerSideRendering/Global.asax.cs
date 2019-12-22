using Codesanook.ReactJS.ServerSideRendering.App_Start;
using System.Web;
using System.Web.Mvc;
using System.Web.Routing;

namespace Codesanook.ReactJS.ServerSideRendering
{
    public class MvcApplication : HttpApplication
    {
        protected void Application_Start()
        {
            AutofacConfig.RegisterAutofac();
            AreaRegistration.RegisterAllAreas();
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
        }
    }
}
