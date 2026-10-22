import Component from "@glimmer/component";
import { service } from "@ember/service";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import {
  lastPostedAt,
  lastPostedAtTitle,
  ordersByLastPost,
} from "../lib/last-post-activity";

// the same for the mobile layout, which renders the time itself; core's
// content is yielded everywhere else
export default class LastPostMobileActivity extends Component {
  @service router;

  get ordersByLastPost() {
    return ordersByLastPost(this.router);
  }

  get lastPostedAt() {
    return lastPostedAt(this.args.outletArgs.topic);
  }

  get title() {
    return lastPostedAtTitle(this.args.outletArgs.topic);
  }

  <template>
    {{#if this.ordersByLastPost}}
      <span title={{this.title}} class="age activity">
        <a href={{@outletArgs.topic.lastPostUrl}}>{{dFormatDate
            this.lastPostedAt
            format="tiny"
            noTitle="true"
          }}</a>
      </span>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
