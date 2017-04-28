#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class SearchPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :member_urls do
    noko.css('.search-result-item a').map { |a| a.attr('href') }
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

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

member_urls = %w[a e i o u].flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(response: Scraped::Request.new(url: url).response).member_urls
end.uniq

# The search index and list pages seem to be missing some members of
# the National Assembly, so add them manually to the pages to be scraped:
member_urls |= [
  'http://www.nass.gov.ng/mp/profile/91',  # Sen. LILIAN UCHE EKWUNIFE
  'http://www.nass.gov.ng/mp/profile/302', # Hon. CHINDA KINGSLEY OGUNDU
  'http://www.nass.gov.ng/mp/profile/306', # Hon. NSIEGBE BLESSING IBIBA
  'http://www.nass.gov.ng/mp/profile/506', # Sen. OHUABUNWA AZIKIWE MAO
  'http://www.nass.gov.ng/mp/profile/519', # Sen. HUSSAIN EGYE SALIHU
  'http://www.nass.gov.ng/mp/profile/520', # Sen. ABDUL ABDULRAHMAN ABUBAKAR
  'http://www.nass.gov.ng/mp/profile/527', # Hon. JACOBSON NBINA BARINEKA
  'http://www.nass.gov.ng/mp/profile/538', # Hon. DEKOR ROBINSON DUMNAMENE
  'http://www.nass.gov.ng/mp/profile/577', # Hon. PHILIP SHAIBU
  'http://www.nass.gov.ng/mp/profile/631', # Hon. EMERENGWA SUNDAY BONIFACE
  'http://www.nass.gov.ng/mp/profile/635', # Hon. Dennis Nnamdi Agbo
  'http://www.nass.gov.ng/mp/profile/646', # Hon. KWAMOTI BITRUS LAORI
  'http://www.nass.gov.ng/mp/profile/664', # Hon. BELLO ABDULLAHI
  'http://www.nass.gov.ng/mp/profile/675', # Hon. Betty Jocelyn Apiafi
  'http://www.nass.gov.ng/mp/profile/812', # Sen. OSINAKACHUKWU T IDEOZU
  'http://www.nass.gov.ng/mp/profile/826', # Hon. D Goodhead Boma
  'http://www.nass.gov.ng/mp/profile/831', # Hon. Jerome Eke
  'http://www.nass.gov.ng/mp/profile/836', # Hon. AWAJI-INOMBEK DAGOMIE ABIANTE
  'http://www.nass.gov.ng/mp/profile/839', # Hon. KENNETH ANAYO CHIKERE
  'http://www.nass.gov.ng/mp/profile/876', # Sen. GEORGE THOMPSON SEKIBO
  'http://www.nass.gov.ng/mp/profile/884', # Hon. GOGO BRIGHT TAMUNO
  'http://www.nass.gov.ng/mp/profile/891', # Sen. Ahmed .Salau Ogembe
  'http://www.nass.gov.ng/mp/profile/896', # Hon. BROWN RANDOLPH IWO ONYERE
  'http://www.nass.gov.ng/mp/profile/937', # Sen. OLAKA JOHNSON NWOGU
  'http://www.nass.gov.ng/mp/profile/952', # Hon. Ugwuegede Ikechukwu
]

def scrape(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
data = member_urls.map { |url| scrape(url => MemberPage).to_h.merge(term: 8) }
# puts data.map { |r| r.reject { |k, v| v.to_s.empty? }.sort_by { |k, v| k }.to_h }
ScraperWiki.save_sqlite(%i[id name term], data)
