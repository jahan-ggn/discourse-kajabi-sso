import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
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

export default class KajabiLoginModal extends Component {
  @service router;
  @service siteSettings;

  @tracked email = "";
  @tracked loading = false;
  @tracked sent = false;
  @tracked errorMessage = null;

  get canSubmit() {
    return this.email?.trim()?.length > 0 && !this.loading;
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
        data: {
          login: this.email.trim(),
        },
      });

      if (result.success === "OK" || result.success === true) {
        this.sent = true;
      } else {
        this.errorMessage =
          result.error || this.siteSettings.kajabi_sso_error_generic;
      }
    } catch (e) {
      this.errorMessage =
        e?.jqXHR?.responseJSON?.errors?.join(", ") ||
        e?.jqXHR?.responseJSON?.error ||
        this.siteSettings.kajabi_sso_error_generic;
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

  <template>
    <DModal
      @title={{this.siteSettings.kajabi_sso_modal_title}}
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
              {{this.siteSettings.kajabi_sso_success_message}}
            </p>
          </div>
        {{else}}
          <div class="kajabi-login-modal__form">
            <label for="kajabi-login-email" class="kajabi-login-modal__label">
              {{this.siteSettings.kajabi_sso_email_label}}
            </label>

            <Input
              id="kajabi-login-email"
              class="kajabi-login-modal__input"
              @value={{this.email}}
              @type="email"
              placeholder={{this.siteSettings.kajabi_sso_email_placeholder}}
              {{on "input" this.updateEmail}}
              disabled={{this.loading}}
            />

            <p class="kajabi-login-modal__help">
              {{this.siteSettings.kajabi_sso_help_text}}
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
            @translatedLabel={{this.siteSettings.kajabi_sso_done_button}}
            @action={{this.closeModal}}
          />
        {{else}}
          <DButton
            class="btn-primary"
            @translatedLabel={{this.siteSettings.kajabi_sso_button_text}}
            @action={{this.sendLink}}
            @disabled={{not this.canSubmit}}
          />
          <DModalCancel @close={{this.closeModal}} />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
