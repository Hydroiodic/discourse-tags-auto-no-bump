# frozen_string_literal: true

RSpec.describe TagsAutoNoBump do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:no_bump_tag) { Fabricate(:tag, name: "no-bump") }
  fab!(:other_tag) { Fabricate(:tag, name: "other") }
  fab!(:topic) { Fabricate(:topic, tags: [no_bump_tag, other_tag]) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }
  fab!(:plain_topic) { Fabricate(:topic, tags: [other_tag]) }
  fab!(:plain_first_post) { Fabricate(:post, topic: plain_topic) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tags_auto_no_bump_enabled = true
    SiteSetting.tags_auto_no_bump_tags = "no-bump"

    freeze_time
    topic.update_columns(bumped_at: 1.day.ago)
    plain_topic.update_columns(bumped_at: 1.day.ago)
  end

  def reply(to_topic)
    PostCreator.create!(user, topic_id: to_topic.id, raw: "This is a reply that is long enough.")
  end

  describe ".no_bump?" do
    it "is true only for topics with a configured tag" do
      expect(described_class.no_bump?(topic)).to eq(true)
      expect(described_class.no_bump?(plain_topic)).to eq(false)
    end

    it "is false when the plugin is disabled or no tag is configured" do
      SiteSetting.tags_auto_no_bump_enabled = false
      expect(described_class.no_bump?(topic)).to eq(false)

      SiteSetting.tags_auto_no_bump_enabled = true
      SiteSetting.tags_auto_no_bump_tags = ""
      expect(described_class.no_bump?(topic)).to eq(false)
    end
  end

  describe "replying" do
    it "does not bump a topic with a configured tag but still updates the last post" do
      post = reply(topic)
      topic.reload

      expect(topic.bumped_at).to eq_time(1.day.ago)
      expect(topic.last_posted_at).to eq_time(post.created_at)
      expect(topic.last_post_user_id).to eq(user.id)
    end

    it "bumps topics without a configured tag" do
      reply(plain_topic)
      expect(plain_topic.reload.bumped_at).to eq_time(Time.zone.now)
    end

    it "bumps again as soon as the tag is removed" do
      topic.update!(tags: [other_tag])
      reply(topic)
      expect(topic.reload.bumped_at).to eq_time(Time.zone.now)
    end

    it "bumps when the plugin is disabled" do
      SiteSetting.tags_auto_no_bump_enabled = false
      reply(topic)
      expect(topic.reload.bumped_at).to eq_time(Time.zone.now)
    end

    it "does not publish the topic to the latest channel" do
      Jobs.run_immediately!

      expect(MessageBus.track_publish("/latest") { reply(topic) }).to be_empty

      messages = MessageBus.track_publish("/latest") { reply(plain_topic) }
      expect(messages.map { |message| message.data["topic_id"] }).to include(plain_topic.id)
    end
  end

  it "sets bumped_at as usual when a topic is created with a configured tag" do
    post =
      PostCreator.create!(
        admin,
        title: "A brand new topic with the no-bump tag",
        raw: "This is the first post of a brand new topic.",
        tags: ["no-bump"],
      )
    expect(post.topic.bumped_at).to eq_time(Time.zone.now)
  end

  describe "editing a wiki first post" do
    def edit_wiki(post)
      post.update!(wiki: true)
      PostRevisor.new(post).revise!(
        admin,
        { raw: "The wiki content has been changed a lot." },
        force_new_version: true,
      )
    end

    it "does not bump a topic with a configured tag" do
      edit_wiki(first_post)
      expect(topic.reload.bumped_at).to eq_time(1.day.ago)
    end

    it "bumps topics without a configured tag" do
      edit_wiki(plain_first_post)
      expect(plain_topic.reload.bumped_at).to eq_time(Time.zone.now)
    end
  end

  # core resets bumped_at to the remaining last reply, which bumps a topic
  # whose replies never bumped it
  describe "removing the last reply" do
    def two_replies(to_topic)
      earlier = reply(to_topic)
      earlier.update_columns(created_at: 1.hour.ago)
      reply(to_topic)
    end

    it "does not move bumped_at when the last reply is deleted" do
      PostDestroyer.new(admin, two_replies(topic)).destroy
      expect(topic.reload.bumped_at).to eq_time(1.day.ago)
    end

    it "does not move bumped_at when the last reply is hidden" do
      two_replies(topic).hide!(PostActionType.types[:off_topic])
      expect(topic.reload.bumped_at).to eq_time(1.day.ago)
    end

    it "resets bumped_at for topics without a configured tag" do
      PostDestroyer.new(admin, two_replies(plain_topic)).destroy
      expect(plain_topic.reload.bumped_at).to eq_time(1.hour.ago)
    end
  end

  describe "moving posts" do
    fab!(:source_topic, :topic)
    fab!(:source_first_post) { Fabricate(:post, topic: source_topic) }

    def move_reply_to(destination)
      moved = Fabricate(:post, topic: source_topic)
      source_topic.move_posts(admin, [moved.id], destination_topic_id: destination.id)
    end

    it "does not bump a destination topic with a configured tag" do
      move_reply_to(topic)
      expect(topic.reload.bumped_at).to eq_time(1.day.ago)
    end

    it "bumps destination topics without a configured tag" do
      move_reply_to(plain_topic)
      expect(plain_topic.reload.bumped_at).to eq_time(Time.zone.now)
    end
  end
end
