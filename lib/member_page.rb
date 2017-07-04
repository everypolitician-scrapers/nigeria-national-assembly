require 'scraped'

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :id do
    url.to_s.split('/').last
  end

  field :title do
    name_with_title[TITLE_RE, 1]
  end

  field :shorter_name do
    name_with_title.gsub(TITLE_RE, '')
  end

  field :name do
    noko.xpath('.//h1/text()').text.tidy.gsub(TITLE_RE, '')
  end

  field :constituency do
    box.xpath('.//th[text()="Constituency"]/following-sibling::td').text.tidy
  end

  field :state do
    box.xpath('.//th[text()="State"]/following-sibling::td').text.tidy
  end

  field :chamber do
    box.xpath('.//th[text()="Chamber"]/following-sibling::td').text.tidy
  end

  field :position do
    box.xpath('.//th[text()="Position"]/following-sibling::td/span').text.tidy
  end

  field :js_position do
    js = noko.css('script:contains("positions")')
    pos = js.to_s[/if\("(.*)" == "Sen"\)\{/, 1]
    raise "Unexpected js_position: #{pos}" unless %w[Sen Hon].include?(pos)
    pos
  end

  field :party do
    party_node_match.captures.first
  end

  field :party_id do
    party_node_match.captures.last
  end

  field :image do
    image_url = box.css('.carousel-inner img/@src').text
    image_url.include?('/avatar.jpg') ? nil : image_url
  end

  field :source do
    url.to_s
  end

  field :area do
    constituency.empty? ? '' : [constituency, state].join(', ')
  end

  field :phone do
    noko.css('.fa-phone').xpath('./following-sibling::text()').first.text.tidy
  end

  private

  def box
    noko.css('.front-carousel')
  end

  def party_node
    box.xpath('.//th[text()="Party"]/following-sibling::td').text
  end

  def party_node_match
    party_node.match(/^(.*)\s+\((.*)\)\s*$/) || abort("Bad party: #{party_node}")
  end

  TITLE_RE = /^(Hon\.|Sen\.) /

  def name_with_title
    box.xpath('.//th[text()="Name"]/following-sibling::td').text.tidy
  end
end
