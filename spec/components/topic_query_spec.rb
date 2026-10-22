# frozen_string_literal: true

describe TopicQuery do
  context "with suppress tags from latest configured" do
    fab!(:user) { Fabricate(:user, created_at: 1.day.ago) }
    fab!(:category)
    fab!(:tag) { Fabricate(:tag, name: "suppressed") }
    fab!(:other_tag) { Fabricate(:tag, name: "other") }
    fab!(:topic1, :topic)
    fab!(:topic2) { Fabricate(:topic, category: category, tags: [tag, other_tag]) }
    fab!(:topic3) { Fabricate(:topic, tags: [other_tag]) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tags_suppressed_from_latest = tag.name
    end

    it "removes topics with suppressed tags" do
      topics = TopicQuery.new.list_latest.topics
      expect(topics).to include(topic1, topic3)
      expect(topics).not_to include(topic2)
    end

    it "removes them from /filter and unseen, which also use the latest results" do
      expect(TopicQuery.new(user, q: "tag:suppressed").list_filter.topics).to be_empty
      expect(TopicQuery.new(user).list_unseen.topics).not_to include(topic2)
    end

    it "keeps them on tag and category pages" do
      expect(TopicQuery.new(nil, tags: [tag.name]).list_latest.topics).to contain_exactly(topic2)
      expect(TopicQuery.new(nil, category: category.id).list_latest.topics).to include(topic2)
    end

    it "keeps them in new, unread, top and hot" do
      expect(TopicQuery.new(user).list_new.topics).to include(topic2)

      topic2.update_columns(highest_post_number: 2)
      TopicUser.create!(
        user: user,
        topic: topic2,
        last_read_post_number: 1,
        notification_level: TopicUser.notification_levels[:tracking],
      )
      expect(TopicQuery.new(user).list_unread.topics).to include(topic2)

      TopTopic.create!(topic: topic2, all_score: 1)
      expect(TopicQuery.new.list_top_for(:all).topics).to include(topic2)

      TopicHotScore.create!(topic: topic2, score: 1)
      expect(TopicQuery.new.list_hot.topics).to include(topic2)
    end

    it "suppresses the target tag of a configured synonym" do
      Fabricate(:tag, name: "suppressed-synonym", target_tag: tag)
      SiteSetting.tags_suppressed_from_latest = "suppressed-synonym"
      expect(TopicQuery.new.list_latest.topics).not_to include(topic2)
    end

    it "does nothing when no tag is configured or tagging is disabled" do
      SiteSetting.tags_suppressed_from_latest = ""
      expect(TopicQuery.new.list_latest.topics).to include(topic2)

      SiteSetting.tags_suppressed_from_latest = tag.name
      SiteSetting.tagging_enabled = false
      expect(TopicQuery.new.list_latest.topics).to include(topic2)
    end
  end
end
