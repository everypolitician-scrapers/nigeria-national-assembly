#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
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
  ScraperWiki.save_sqlite([:id, :name, :term], data)
end

links = %w(a e i o u).map { |v|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % v
  noko = noko_for(url)
  noko.css('.search-result-item a').select { |a| a.text.include? 'Hon. ' }.map { |a| URI.join url, a.attr('href') }
}.flatten.uniq.each do |url|
  scrape_mp url
end
