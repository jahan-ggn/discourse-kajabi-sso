import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class KajabiAdminOffers extends Component {
  @service toasts;

  @tracked offers = [];
  @tracked loading = true;
  @tracked error = null;

  constructor() {
    super(...arguments);
    this.loadOffers();
  }

  async loadOffers() {
    try {
      const result = await ajax("/kajabi-sso/admin/offers");
      this.offers = result.offers || [];
    } catch (e) {
      this.error =
        e.jqXHR?.responseJSON?.error ||
        i18n("discourse_kajabi_sso.admin.fetch_error");
    } finally {
      this.loading = false;
    }
  }

  @action
  copyToClipboard(text) {
    navigator.clipboard.writeText(text);
    this.toasts.success({
      data: { message: i18n("discourse_kajabi_sso.admin.copied") },
    });
  }

  <template>
    <div class="kajabi-admin-offers">
      {{#if this.loading}}
        <div class="kajabi-admin-offers__loading">
          <DConditionalLoadingSpinner @condition={{true}} />
        </div>
      {{else if this.error}}
        <div class="kajabi-admin-offers__error">{{this.error}}</div>
      {{else if this.offers.length}}
        <table class="kajabi-admin-offers__table">
          <thead>
            <tr>
              <th>{{i18n "discourse_kajabi_sso.admin.id"}}</th>
              <th>{{i18n "discourse_kajabi_sso.admin.title"}}</th>
              <th>{{i18n "discourse_kajabi_sso.admin.internal_title"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.offers as |offer|}}
              <tr>
                <td>{{offer.id}}</td>
                <td>{{offer.title}}</td>
                <td>{{offer.internal_title}}</td>
                <td>
                  <DButton
                    @action={{fn this.copyToClipboard offer.id}}
                    @translatedLabel={{i18n
                      "discourse_kajabi_sso.admin.copy_id"
                    }}
                    class="btn-small"
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <div class="kajabi-admin-offers__empty">{{i18n
            "discourse_kajabi_sso.admin.no_offers"
          }}</div>
      {{/if}}
    </div>
  </template>
}
