# frozen_string_literal: true

# name: discourse-tags-suppressed
# about: Suppress tags from latest topics page.
# version: 0.1
# authors: Hydroiodic

after_initialize do
  if TopicQuery.respond_to?(:results_filter_callbacks)
    remove_suppressed_tag_topics =
      Proc.new do |list_type, result, _user, options|
        tag_names = (SiteSetting.tags_suppressed_from_latest.presence || "").split("|")

        if !SiteSetting.tagging_enabled || tag_names.blank? || list_type != :latest ||
             options[:category] || options[:tags]
          next result
        end

        # topics are tagged with the target of a synonym, never with the synonym itself
        tag_ids =
          Tag
            .where_name(tag_names)
            .pluck(:id, :target_tag_id)
            .map { |id, target_id| target_id || id }
        next result if tag_ids.blank?

        result.where(<<~SQL, tag_ids)
          NOT EXISTS (
            SELECT 1
            FROM topic_tags suppressed_topic_tags
            WHERE suppressed_topic_tags.topic_id = topics.id
              AND suppressed_topic_tags.tag_id IN (?)
          )
        SQL
      end

    TopicQuery.results_filter_callbacks << remove_suppressed_tag_topics
  end
end
