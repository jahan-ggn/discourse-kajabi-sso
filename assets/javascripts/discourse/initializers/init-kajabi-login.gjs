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
        @service router;

        beforeModel(transition) {
          transition.abort();
          this.modal.show(KajabiLoginModal);
        }
      }
  );
});
