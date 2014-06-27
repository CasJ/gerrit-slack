require 'json'

class Update
  attr_reader :raw_json, :json

  def initialize(raw_json)
    @raw_json = raw_json
    @json = JSON.parse(raw_json)
  end

  def type
    json['type']
  end

  def project
    json['change']['project'] if json['change']
  end

  def comment_added?
    type == 'comment-added'
  end

  def merged?
    type == 'change-merged'
  end

  def human?
    !['hudson', 'firework'].include?(json['author']['username'])
  end

  def jenkins?
    comment_added? && json['author']['username'] == 'hudson'
  end

  def build_successful?
    comment =~ /Build Successful/
  end

  def build_failed?
    comment =~ /Build Failed/
  end

  def comment
    frd_lines = []
    json['comment'].split("\n\n").each { |line|
      next if line =~ /Patch Set \d+/
      break if line =~ /Reviewer (DID NOT )?check/
      frd_lines << line
    }
    frd_lines.join("\n\n")
  end

  def commit
    "<#{json['change']['url']}|[#{json['change']['project']}] #{subject}> (by #{owner})"
  end

  def owner
    json['change']['owner']['username']
  end

  def subject
    json['change']['subject']
  end

  def wip?
    !!(subject.match /^wip[^a-zA-Z]+/i)
  end

  def author
    json['author']['username']
  end

  def approvals
    json['approvals']
  end

  def code_review_approved?
    has_approval?('Code-Review', '2')
  end

  def code_review_tentatively_approved?
    has_approval?('Code-Review', '1')
  end

  def code_review_rejected?
    has_approval?('Code-Review', '-1') || has_approval?('Code-Review', '-2')
  end

  def qa_approved?
    has_approval?('QA-Review', '1')
  end

  def qa_rejected?
    has_approval?('QA-Review', '-1')
  end

  def product_approved?
    has_approval?('Product-Review', '1')
  end

  def product_rejected?
    has_approval?('Product-Review', '-1')
  end

  def has_approval?(type, value)
    approvals && \
      approvals.find { |approval| approval['type'] == type && approval['value'] == value }
  end

  def channels(config)
    config.map do |channel, opts|
      channel if \
        opts['project'].include?("#{project}*") ||
        (opts['project'].include?(project) && opts['owner'].include?(owner))
    end.reject(&:nil?)
  end
end
