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

  field :members do
    noko.css('.search-result-item a').map do |a|
      {
        name: a.text,
        url:  a.attr('href'),
      }
    end
  end
end

class MemberPage < Scraped::HTML
  decorator Scraped::Response::Decorator::AbsoluteUrls

  field :id do
    url.to_s.split('/').last
  end

  field :name do
    box.xpath('.//th[text()="Name"]/following-sibling::td').text.tidy.sub('Hon. ', '')
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
end

members = %w(a e i o u).flat_map do |vowel|
  url = 'http://www.nass.gov.ng/search/mps/?search=%s' % vowel
  SearchPage.new(response: Scraped::Request.new(url: url).response).members
end.uniq

data = members.select { |m| m[:name].start_with? 'Hon' }.map do |mem|
  MemberPage.new(response: Scraped::Request.new(url: mem[:url]).response).to_h
end
# puts data

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
ScraperWiki.save_sqlite(%i(id name term), data)
