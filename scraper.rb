#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'field_serializer'
require 'nokogiri'
require 'pry'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

# require 'scraped_page_archive/open-uri'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

class Page
  include FieldSerializer

  def initialize(url)
    @url = url
  end

  def noko
    @noko ||= Nokogiri::HTML(open(url).read)
  end

  private

  attr_reader :url
end

class SearchPage < Page
  field :members do
    noko.css('.search-result-item a').map do |a|
      {
        name: a.text,
        url: URI.join(url, a.attr('href')),
      }
    end
  end

  field :url do
    url
  end

  private

  attr_reader :search_string
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end


def scrape_mp(url)
  noko = noko_for(url)

  box = noko.css('.front-carousel')

  party_node = box.xpath('.//th[text()="Party"]/following-sibling::td').text
  if found = party_node.match(/^(.*)\s+\((.*)\)\s*$/)
    party, party_id = found.captures
  else
    warn "ODD PARTY: #{party_node}"
    party, party_id = party_node, "Unknown"
  end

  data = { 
    id: url.to_s.split('/').last,
    name: box.xpath('.//th[text()="Name"]/following-sibling::td').text.tidy.sub('Hon. ',''),
    constituency: box.xpath('.//th[text()="Constituency"]/following-sibling::td').text.tidy,
    state: box.xpath('.//th[text()="State"]/following-sibling::td').text.tidy,
    chamber: box.xpath('.//th[text()="Chamber"]/following-sibling::td').text.tidy,
    party: party,
    party_id: party_id,
    image: box.css('.carousel-inner img/@src').text,
    term: 2015,
    source: url.to_s,
  }
  data[:area] = "%s, %s" % [data[:constituency], data[:state]]
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
  warn data
  ScraperWiki.save_sqlite([:id, :name, :term], data)
end

members = %w(a e i o u).flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(url).to_h[:members]
end.uniq

members.select { |m| m[:name].start_with? 'Hon' }.each do |mem|
  scrape_mp mem[:url]
end
