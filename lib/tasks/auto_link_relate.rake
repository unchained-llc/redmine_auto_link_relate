# frozen_string_literal: true

namespace :redmine_auto_link_relate do
  desc 'Scan all comments and relate issues based on internal links'
  task relate_issues: :environment do
    Journal.includes(:journalized).find_each do |journal|
      next unless journal.journalized.is_a?(Issue) && journal.notes.present?

      issue = journal.journalized
      related_issue_ids = extract_issue_ids(journal.notes)
      related_issue_ids.each do |related_issue_id|
        related_issue = Issue.find_by_id(related_issue_id)
        next unless related_issue

        # Skip if the relation already exists
        if IssueRelation.exists?(issue_from_id: issue.id, issue_to_id: related_issue.id)
          puts "Relation already exists: ##{issue.id} -> ##{related_issue.id}"
          next
        end

        # Skip if the relation would create a circular reference
        if circular_relation?(issue, related_issue)
          puts "Skipped circular relation: ##{issue.id} -> ##{related_issue.id}"
          next
        end

        # Skip if the issue already has other specific relationships
        if has_existing_relationship?(issue, related_issue)
          puts "Skipped due to existing relationship: ##{issue.id} -> ##{related_issue.id}"
          next
        end

        begin
          IssueRelation.create!(issue_from: issue, issue_to: related_issue, relation_type: 'relates')
          puts "Related issue ##{issue.id} to issue ##{related_issue.id}"
        rescue ActiveRecord::RecordInvalid => e
          puts "Failed to relate issue ##{issue.id} to issue ##{related_issue.id}: #{e.message}"
        end
      end
    end
    puts 'All comments have been processed.'
  end

  def extract_issue_ids(notes)
    notes.scan(/#(\d+)/).flatten.map(&:to_i)
  end

  def circular_relation?(issue, related_issue)
    visited = Set.new
    queue = [related_issue]

    while queue.any?
      current = queue.shift
      return true if current == issue

      next if visited.include?(current.id)
      visited.add(current.id)

      # Add all related issues to the queue
      current.relations_from.each { |rel| queue << rel.issue_to if rel.issue_to }
      current.relations_to.each { |rel| queue << rel.issue_from if rel.issue_from }
    end

    false
  end

  def has_existing_relationship?(issue, related_issue)
    # Check for parent-child relationship
    return true if issue.parent_id == related_issue.id || related_issue.parent_id == issue.id

    # Check for other specific relationships
    related_types = %w[duplicates duplicated blocks blocked precedes follows copied_to copied_from]
    issue.relations_from.each do |relation|
      return true if relation.issue_to == related_issue && related_types.include?(relation.relation_type)
    end
    issue.relations_to.each do |relation|
      return true if relation.issue_from == related_issue && related_types.include?(relation.relation_type)
    end

    false
  end
end
