import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import KajabiLoginModal from "../components/kajabi-login-modal";

export default apiInitializer((api) => {
  api.modifyClass(
    "route:login",
    (Superclass) =>
      class extends Superclass {
        @service modal;
        @service siteSettings;

        beforeModel(transition) {
          if (!this.siteSettings.kajabi_sso_enabled) {
            return super.beforeModel?.(transition);
          }

          transition.abort();
          this.modal.show(KajabiLoginModal);
        }
      }
  );

  api.modifyClass(
    "route:signup",
    (Superclass) =>
      class extends Superclass {
        @service siteSettings;

        beforeModel(transition) {
          if (!this.siteSettings.kajabi_sso_enabled) {
            return super.beforeModel?.(transition);
          }

          transition.abort();
          window.location.href =
            this.siteSettings.kajabi_signup_redirect_url || "#";
        }
      }
  );

  const currentUser = api.getCurrentUser();
  if (currentUser) {
    const messageBus = api.container.lookup("service:message-bus");
    messageBus.subscribe(`/user/${currentUser.id}`, (data) => {
      if (data.type === "refresh_groups") {
        currentUser.refresh();
      }
    });
  }
});
