# frozen_string_literal: true

RSpec.describe "Activity column on the pages of the configured tags" do
  fab!(:user)
  fab!(:no_bump_tag) { Fabricate(:tag, name: "no-bump") }
  fab!(:other_tag) { Fabricate(:tag, name: "other") }
  fab!(:topic) { Fabricate(:topic, tags: [no_bump_tag, other_tag]) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  before do
    enable_current_plugin
    SiteSetting.tagging_enabled = true
    SiteSetting.tags_auto_no_bump_enabled = true
    SiteSetting.tags_auto_no_bump_tags = "no-bump"
    topic.update_columns(
      created_at: 10.days.ago,
      bumped_at: 5.days.ago,
      last_posted_at: 2.hours.ago,
    )
    sign_in(user)
  end

  # the mobile layout nests span.age.activity in div.activity
  def activity(selector = ".activity")
    find(".topic-list-item[data-topic-id='#{topic.id}'] #{selector}")
  end

  it "shows the last post time on the pages of a configured tag" do
    visit("/tag/no-bump")
    expect(activity).to have_text("2h")

    visit("/tags/intersection/no-bump/other")
    expect(activity).to have_text("2h")
  end

  it "shows the bump time on other pages" do
    visit("/tag/other")
    expect(activity).to have_text("5d")

    visit("/latest")
    expect(activity).to have_text("5d")
  end

  it "shows the last post time in the mobile layout", mobile: true do
    visit("/tag/no-bump")
    expect(activity(".age.activity")).to have_text("2h")

    visit("/latest")
    expect(activity(".age.activity")).to have_text("5d")
  end
end
