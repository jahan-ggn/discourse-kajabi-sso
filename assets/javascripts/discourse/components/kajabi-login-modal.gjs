import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { defaultHomepage } from "discourse/lib/utilities";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class KajabiLoginModal extends Component {
  @service router;

  @tracked email = "";
  @tracked loading = false;
  @tracked sent = false;
  @tracked errorMessage = null;

  get canSubmit() {
    return this.email.trim().length > 0 && !this.loading;
  }

  @action
  updateEmail(event) {
    this.email = event.target.value;
    this.errorMessage = null;
  }

  @action
  async sendLink() {
    if (!this.canSubmit) {
      return;
    }

    this.loading = true;
    this.errorMessage = null;

    try {
      const result = await ajax("/u/email-login", {
        type: "POST",
        data: { login: this.email.trim() },
      });

      if (result.success === "OK" || result.success === true) {
        this.sent = true;
      } else {
        this.errorMessage =
          result.error ||
          i18n("discourse_kajabi_sso.login_modal.error_generic");
      }
    } catch (e) {
      this.errorMessage = this.#extractError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  closeModal() {
    this.args.closeModal?.();
    if (this.router.currentRouteName === "login") {
      this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
  }

  #extractError(error) {
    const payload = error?.jqXHR?.responseJSON;
    if (payload?.errors?.length) {
      return payload.errors.join(", ");
    }
    if (payload?.error) {
      return payload.error;
    }
    return i18n("discourse_kajabi_sso.login_modal.error_generic");
  }

  <template>
    <DModal
      @title={{i18n "discourse_kajabi_sso.login_modal.title"}}
      @closeModal={{this.closeModal}}
      class="kajabi-login-modal"
    >
      <:body>
        {{#if this.sent}}
          <div class="kajabi-login-modal__success">
            <span class="kajabi-login-modal__icon--success">
              {{dIcon "check"}}
            </span>
            <p class="kajabi-login-modal__success-text">
              {{i18n "discourse_kajabi_sso.login_modal.success_message"}}
            </p>
          </div>
        {{else}}
          <div class="kajabi-login-modal__form">
            <label for="kajabi-login-email" class="kajabi-login-modal__label">
              {{i18n "discourse_kajabi_sso.login_modal.email_label"}}
            </label>

            <input
              id="kajabi-login-email"
              class="kajabi-login-modal__input"
              type="email"
              value={{this.email}}
              placeholder={{i18n
                "discourse_kajabi_sso.login_modal.email_placeholder"
              }}
              {{on "input" this.updateEmail}}
              disabled={{this.loading}}
            />

            <p class="kajabi-login-modal__help">
              {{i18n "discourse_kajabi_sso.login_modal.help_text"}}
            </p>

            {{#if this.errorMessage}}
              <div
                class="kajabi-login-modal__alert kajabi-login-modal__alert--error"
              >
                <span
                  class="kajabi-login-modal__icon kajabi-login-modal__icon--error"
                >
                  {{dIcon "xmark"}}
                </span>
                <span class="kajabi-login-modal__alert-text">
                  {{this.errorMessage}}
                </span>
              </div>
            {{/if}}
          </div>
        {{/if}}
      </:body>

      <:footer>
        {{#if this.sent}}
          <DButton
            class="btn-primary"
            @translatedLabel={{i18n
              "discourse_kajabi_sso.login_modal.done_button"
            }}
            @action={{this.closeModal}}
          />
        {{else}}
          <DButton
            class="btn-primary"
            @translatedLabel={{i18n
              "discourse_kajabi_sso.login_modal.button_text"
            }}
            @action={{this.sendLink}}
            @disabled={{not this.canSubmit}}
          />
          <DModalCancel @close={{this.closeModal}} />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
