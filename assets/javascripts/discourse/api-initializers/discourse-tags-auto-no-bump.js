import { apiInitializer } from "discourse/lib/api";
import LastPostActivityCell from "../components/last-post-activity-cell";
import LastPostMobileActivity from "../components/last-post-mobile-activity";

// the lists of the configured tags are ordered by the last post, so their
// activity column shows that time; every other list keeps core's cell
export default apiInitializer((api) => {
  api.registerValueTransformer(
    "topic-list-columns",
    ({ value: columns, context }) => {
      if (context.listContext === "discovery") {
        columns.replace("activity", { item: LastPostActivityCell });
      }
      return columns;
    }
  );

  api.renderInOutlet(
    "topic-list-item-mobile-bumped-at",
    LastPostMobileActivity
  );
});
