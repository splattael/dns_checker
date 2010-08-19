#!/usr/bin/env ruby

require 'rubygems'
require 'bundler'

Bundler.setup

require 'net/dns/resolver'
require 'term/ansicolor'

COLORS = {
  :fail => :red,
  :pass => :green,
  :warn => :yellow
}

class String
  include Term::ANSIColor
end

def resolve(domain, resolver=nil)
  resolver ||= Net::DNS::Resolver.new
  resolver.search(domain)
end

def resolve_at(domain, nameserver)
  resolver = Net::DNS::Resolver.new
  resolver.nameservers = nameserver
  resolver.search(domain)
end

def resolve_address(domain)
  resolve(domain).answer.first.address.to_s
end

def resolve_root_nameserver(domain)
  tld = domain.split(/\./)[-1]
  @cache ||= {}
  @cache[tld] ||= resolve_at(domain, ROOT_NAMESERVER).additional.select { |a| Net::DNS::RR::A === a }.choice.address.to_s
end

def extract_ns(authority)
  authority.select { |a| Net::DNS::RR::NS === a }.map(&:nsdname).sort.first
end

def check(domain)
  nameserver = resolve_root_nameserver(domain)

  at_root = extract_ns(resolve_at(domain, nameserver).authority)
  local = extract_ns(resolve_at(domain, MY_NAMESERVER).authority)

  if at_root != local
    write :fail, domain, "'#{at_root}' != '#{local}'"
  else
    write :pass, domain
  end
rescue => e
  write :warn, domain, e
end

def write(type, domain, reason=nil)
  color = COLORS[type]
  reason = ": #{reason.to_s.cyan.bold}" if reason
  puts "#{type.to_s.upcase.send(color).bold} #{domain}#{reason}"
end

my_nameserver = ARGV.shift or abort("usage: echo 'example.com' | #{$0} my-nameserver")

ROOT_NAMESERVER = resolve_address("a.root-servers.net")
MY_NAMESERVER = resolve_address(my_nameserver)

STDIN.each do |domain|
  domain.chomp!

  check domain
end
