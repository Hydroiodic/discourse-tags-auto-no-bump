import { longDate } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

// The server orders the lists of the configured tags by the last post and
// flags them. Route models of topic lists, including the tag pages that the
// discovery service does not count as discovery routes, keep the list there.
export function ordersByLastPost(router) {
  return !!router.currentRoute?.attributes?.list?.topic_list
    ?.tags_auto_no_bump_last_post_order;
}

// the server orders topics without a last post by their creation time
export function lastPostedAt(topic) {
  return topic.last_posted_at
    ? new Date(topic.last_posted_at)
    : topic.createdAt;
}

// like core's Topic#bumpedAtTitle
export function lastPostedAtTitle(topic) {
  const created = i18n("topic.created_at", {
    date: longDate(topic.createdAt),
  });
  const lastPosted = lastPostedAt(topic);
  if (
    Math.floor(lastPosted.getTime() / 1000) ===
    Math.floor(topic.createdAt.getTime() / 1000)
  ) {
    return created;
  }
  return `${created}\n${i18n("topic.bumped_at", { date: longDate(lastPosted) })}`;
}
