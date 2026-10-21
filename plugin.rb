# frozen_string_literal: true
# name: tags-auto-no-bump
# about: New replies do not bump topics that carry one of the configured tags
# version: 0.0.1
# authors: Hydroiodic

enabled_site_setting :tags_auto_no_bump_enabled

module ::TagsAutoNoBump
  PLUGIN_NAME = "tags-auto-no-bump"

  # decided from the topic's current tags, so adding or removing a tag
  # takes effect at the next reply without any stored state
  def self.no_bump?(topic)
    return false if !SiteSetting.tags_auto_no_bump_enabled
    tags = SiteSetting.tags_auto_no_bump_tags.split("|")
    tags.present? && topic.tags.any? { |tag| tags.include?(tag.name) }
  end

  # every override calls super, so it composes with core and other plugins

  module PostCreatorExtension
    def update_topic_stats
      @post.no_bump = true if !new_topic? && TagsAutoNoBump.no_bump?(@topic)
      super
    end
  end

  module PostRevisorExtension
    def bump_topic
      return if TagsAutoNoBump.no_bump?(@topic)
      super
    end
  end

  module PostMoverExtension
    def update_last_post_stats
      return super if !TagsAutoNoBump.no_bump?(destination_topic)
      bumped_at = destination_topic.bumped_at
      super
      if destination_topic.bumped_at != bumped_at
        destination_topic.update_columns(bumped_at: bumped_at)
      end
    end
  end

  module TopicExtension
    def reset_bumped_at(post_or_post_id = nil)
      return if TagsAutoNoBump.no_bump?(self)
      super
    end
  end

  module TopicTrackingStateExtension
    def publish_latest(topic, *args)
      return if TagsAutoNoBump.no_bump?(topic)
      super
    end
  end
end

after_initialize do
  ::PostCreator.prepend TagsAutoNoBump::PostCreatorExtension
  ::PostRevisor.prepend TagsAutoNoBump::PostRevisorExtension
  ::PostMover.prepend TagsAutoNoBump::PostMoverExtension
  ::Topic.prepend TagsAutoNoBump::TopicExtension
  ::TopicTrackingState.singleton_class.prepend TagsAutoNoBump::TopicTrackingStateExtension
end
