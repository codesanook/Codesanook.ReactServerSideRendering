using Codesanook.ReactJS.ServerSideRendering.Models;
using System.Web.Mvc;

namespace Codesanook.ReactJS.ServerSideRendering.Controllers
{
    public class HomeController : Controller
    {
        // GET: React
        public ActionResult Index()
        {
            var user = new User()
            {
                FirstName = "Phuong",
                LastName = "XinChao"
            };

            return View(user);
        } 
    }
}