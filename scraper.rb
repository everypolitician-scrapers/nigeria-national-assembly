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

  field :name do
    name_with_title.gsub(TITLE_RE, '')
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
    raise "Unexpected js_position: #{pos}" unless %w(Sen Hon).include?(pos)
    pos
  end

  field :party do
    party_node_match.captures.first
  end

  field :party_id do
    party_node_match.captures.last
  end

  field :image do
    box.css('.carousel-inner img/@src').text
  end

  field :term do
    2015
  end

  field :source do
    url.to_s
  end

  field :area do
    [constituency, state].join(', ')
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

member_urls = %w(a e i o u).flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(response: Scraped::Request.new(url: url).response).member_urls
end.uniq

# The search index and list pages seem to be missing some members of
# the National Assembly, so add them manually to the pages to be scraped:
member_urls |= [
  # Hon. AWAJI-INOMBEK DAGOMIE ABIANTE
  'http://www.nass.gov.ng/mp/profile/836',
  # Hon. BELLO ABDULLAHI
  'http://www.nass.gov.ng/mp/profile/664',
  # Hon. BROWN RANDOLPH IWO ONYERE
  'http://www.nass.gov.ng/mp/profile/896',
  # Hon. DEKOR ROBINSON DUMNAMENE
  'http://www.nass.gov.ng/mp/profile/538',
  # Hon. Dennis Nnamdi Agbo
  'http://www.nass.gov.ng/mp/profile/635',
  # Hon. EMERENGWA SUNDAY BONIFACE
  'http://www.nass.gov.ng/mp/profile/631',
  # Hon. GOGO BRIGHT TAMUNO
  'http://www.nass.gov.ng/mp/profile/884',
  # Hon. JACOBSON NBINA BARINEKA
  'http://www.nass.gov.ng/mp/profile/527',
  # Hon. KENNETH ANAYO CHIKERE
  'http://www.nass.gov.ng/mp/profile/839',
  # Hon. KWAMOTI BITRUS LAORI
  'http://www.nass.gov.ng/mp/profile/646',
  # Hon. NSIEGBE BLESSING IBIBA
  'http://www.nass.gov.ng/mp/profile/306',
  # Hon. Betty Jocelyn Apiafi
  'http://www.nass.gov.ng/mp/profile/675',
  # Hon. D Goodhead Boma
  'http://www.nass.gov.ng/mp/profile/826',
]

data = member_urls.map do |url|
  MemberPage.new(response: Scraped::Request.new(url: url).response).to_h
end
# puts data

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id name term), data)
