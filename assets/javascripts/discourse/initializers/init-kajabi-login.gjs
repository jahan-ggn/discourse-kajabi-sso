import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import KajabiLoginModal from "../components/kajabi-login-modal";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (!siteSettings.kajabi_sso_enabled) {
    return;
  }

  api.modifyClass(
    "route:login",
    (Superclass) =>
      class extends Superclass {
        @service modal;

        beforeModel(transition) {
          transition.abort();
          this.modal.show(KajabiLoginModal);
        }
      }
  );

  api.modifyClass(
    "route:signup",
    (Superclass) =>
      class extends Superclass {
        beforeModel(transition) {
          transition.abort();
          const url = siteSettings.kajabi_signup_redirect_url;
          window.location.href = url || "#";
        }
      }
  );
});
