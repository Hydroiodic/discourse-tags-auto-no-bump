import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import ActivityCell from "discourse/components/topic-list/item/activity-cell";
import coldAgeClass from "discourse/helpers/cold-age-class";
import lazyHash from "discourse/helpers/lazy-hash";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import {
  lastPostedAt,
  lastPostedAtTitle,
  ordersByLastPost,
} from "../lib/last-post-activity";

// core's activity cell, showing the last post time instead of the bump time
// on the lists ordered by the last post
export default class LastPostActivityCell extends Component {
  @service router;

  get ordersByLastPost() {
    return ordersByLastPost(this.router);
  }

  get lastPostedAt() {
    return lastPostedAt(this.args.topic);
  }

  get title() {
    return lastPostedAtTitle(this.args.topic);
  }

  <template>
    {{#if this.ordersByLastPost}}
      <td
        title={{trustHTML this.title}}
        class={{dConcatClass
          "activity num topic-list-data"
          (coldAgeClass @topic.createdAt startDate=this.lastPostedAt class="")
        }}
        ...attributes
      >
        <a href={{@topic.lastPostUrl}} class="post-activity">
          {{~! no whitespace ~}}
          <PluginOutlet
            @name="topic-list-before-relative-date"
            @outletArgs={{lazyHash topic=@topic}}
          />
          {{~dFormatDate this.lastPostedAt format="tiny" noTitle="true"~}}
        </a>
      </td>
    {{else}}
      <ActivityCell @topic={{@topic}} ...attributes />
    {{/if}}
  </template>
}
