import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";
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
    if (messageBus) {
      messageBus.subscribe(`/user/${currentUser.id}`, (data) => {
        if (data.type === "refresh_groups" && data.groups) {
          if (typeof currentUser.set === "function") {
            currentUser.set("groups", data.groups);
          } else {
            currentUser.groups = data.groups;
          }
        }
      });
    }
  }

  api.modifyClass(
    "controller:email-login",
    (Superclass) =>
      class extends Superclass {
        @service router;

        @action
        async finishLogin() {
          let data = {
            second_factor_method: this.secondFactorMethod,
            timezone: moment.tz.guess(),
          };

          if (this.securityKeyCredential) {
            data.second_factor_token = this.securityKeyCredential;
          } else {
            data.second_factor_token = this.secondFactorToken;
          }

          try {
            const result = await ajax({
              url: `/session/email-login/${this.model.token}`,
              type: "POST",
              data,
            });

            if (!result.success) {
              this.set("model.error", result.error);
              return;
            }

            const match = document.cookie.match(/destination_url=([^;]+)/);

            let destination = match ? match[1] : "/";

            const safeMode = new URL(
              this.router.currentURL,
              window.location.origin
            ).searchParams.get("safe_mode");

            if (safeMode) {
              const params = new URLSearchParams();
              params.set("safe_mode", safeMode);
              destination += `?${params.toString()}`;
            }

            DiscourseURL.redirectTo(destination);

            if (match) {
              document.cookie =
                "destination_url=; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";
            }
          } catch (e) {
            popupAjaxError(e);
          }
        }
      }
  );
});
