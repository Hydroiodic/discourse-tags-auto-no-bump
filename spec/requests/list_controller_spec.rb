# frozen_string_literal: true

describe ListController do
  fab!(:tag) { Fabricate(:tag, name: "suppressed") }
  fab!(:topic)
  fab!(:suppressed_topic) { Fabricate(:topic, tags: [tag]) }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.tags_suppressed_from_latest = tag.name
  end

  def topic_ids(path)
    get path
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { |t| t["id"] }
  end

  it "suppresses the topics on /latest but not on the tag page" do
    expect(topic_ids("/latest.json")).to include(topic.id)
    expect(topic_ids("/latest.json")).not_to include(suppressed_topic.id)
    expect(topic_ids("/tag/suppressed.json")).to contain_exactly(suppressed_topic.id)
  end
end
