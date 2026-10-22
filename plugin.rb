# frozen_string_literal: true
# name: discourse-tags-auto-no-bump
# about: New replies do not bump topics that carry one of the configured tags
# version: 0.0.1
# authors: Hydroiodic
# url: https://github.com/Hydroiodic/discourse-tags-auto-no-bump

enabled_site_setting :tags_auto_no_bump_enabled

module ::DiscourseTagsAutoNoBump
  PLUGIN_NAME = "discourse-tags-auto-no-bump"

  # decided from the topic's current tags, so adding or removing a tag
  # takes effect at the next reply without any stored state
  def self.no_bump?(topic)
    return false if !SiteSetting.tags_auto_no_bump_enabled
    tags = SiteSetting.tags_auto_no_bump_tags.split("|")
    tags.present? && topic.tags.any? { |tag| tags.include?(tag.name) }
  end

  # replies do not bump these topics, so the pages of their tags order them by
  # the last post instead, wherever core would order by bumped_at
  def self.order_by_last_post?(order, sort_dir, options, topic_query)
    sort_column = TopicQuery::SORTABLE_MAPPING[order] || "default"
    return false if %w[default bumped_at].exclude?(sort_column)
    # core leaves these lists (new, unread, top, hot...) to their own ordering
    return false if sort_column == "default" && sort_dir == "DESC" && options[:unordered]
    tag_page?(topic_query)
  end

  # the list of a configured tag, also within a category or in an intersection;
  # tag_ids is set by TopicQuery#filter_by_tags before the ordering is applied
  def self.tag_page?(topic_query)
    tag_ids = topic_query.options[:tag_ids]
    tags = SiteSetting.tags_auto_no_bump_tags.split("|")
    tag_ids.present? && tags.present? && Tag.where(id: tag_ids).where_name(tags).exists?
  end

  # every override calls super, so it composes with core and other plugins

  module PostCreatorExtension
    def update_topic_stats
      @post.no_bump = true if !new_topic? && DiscourseTagsAutoNoBump.no_bump?(@topic)
      super
    end
  end

  module PostRevisorExtension
    def bump_topic
      return if DiscourseTagsAutoNoBump.no_bump?(@topic)
      super
    end
  end

  module PostMoverExtension
    def update_last_post_stats
      return super if !DiscourseTagsAutoNoBump.no_bump?(destination_topic)
      bumped_at = destination_topic.bumped_at
      super
      if destination_topic.bumped_at != bumped_at
        destination_topic.update_columns(bumped_at: bumped_at)
      end
    end
  end

  module TopicExtension
    def reset_bumped_at(post_or_post_id = nil)
      return if DiscourseTagsAutoNoBump.no_bump?(self)
      super
    end
  end

  module TopicTrackingStateExtension
    def publish_latest(topic, *args)
      return if DiscourseTagsAutoNoBump.no_bump?(topic)
      super
    end
  end
end

after_initialize do
  ::PostCreator.prepend DiscourseTagsAutoNoBump::PostCreatorExtension
  ::PostRevisor.prepend DiscourseTagsAutoNoBump::PostRevisorExtension
  ::PostMover.prepend DiscourseTagsAutoNoBump::PostMoverExtension
  ::Topic.prepend DiscourseTagsAutoNoBump::TopicExtension
  ::TopicTrackingState.singleton_class.prepend DiscourseTagsAutoNoBump::TopicTrackingStateExtension

  register_modifier(
    :topic_query_apply_ordering_result,
  ) do |result, order, sort_dir, options, topic_query|
    if !DiscourseTagsAutoNoBump.order_by_last_post?(order, sort_dir, options, topic_query)
      next result
    end
    # passed on to the TopicList, so that the client shows the same time
    topic_query.options[:tags_auto_no_bump_last_post_order] = true
    # topics whose posts are all whispers or silent have no last_posted_at
    result.order("COALESCE(topics.last_posted_at, topics.created_at) #{sort_dir}")
  end

  # TopicQuery#create_list builds the TopicList with its options
  add_to_class(:topic_list, :tags_auto_no_bump_last_post_order) do
    !!@opts[:tags_auto_no_bump_last_post_order]
  end

  # the activity column of these lists shows the last post time
  add_to_serializer(
    :topic_list,
    :tags_auto_no_bump_last_post_order,
    include_condition: -> { object.tags_auto_no_bump_last_post_order },
  ) { true }
end
