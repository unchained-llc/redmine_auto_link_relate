# frozen_string_literal: true

module RedmineAutoLinkRelate
  class Hooks < Redmine::Hook::Listener
    def controller_issues_edit_after_save(context = {})
      journal = context[:journal]
      return unless journal

      issue = journal.journalized
      return unless issue.is_a?(Issue)

      related_issue_ids = []

      # 1. Extract issue IDs from comments (notes)
      if journal.notes.present?
        related_issue_ids += extract_issue_ids(journal.notes)
      end

      # 2. Check if the issue description has been changed
      if journal.details.any? { |d| d.prop_key == 'description' }
        Rails.logger.info("Description changed for issue ##{issue.id}, checking for related issues.")
        related_issue_ids += extract_issue_ids(issue.description) if issue.description.present?
      end

      # Process extracted issue IDs and establish relations
      related_issue_ids.uniq.each do |related_issue_id|
        related_issue = Issue.find_by_id(related_issue_id)
        next unless related_issue

        # Skip if the relation already exists
        if IssueRelation.exists?(issue_from_id: issue.id, issue_to_id: related_issue.id)
          Rails.logger.info("Relation already exists: ##{issue.id} -> ##{related_issue.id}")
          next
        end

        # Skip if the relation would create a circular dependency
        if circular_relation?(issue, related_issue)
          Rails.logger.info("Skipped circular relation: ##{issue.id} -> ##{related_issue.id}")
          next
        end

        # Skip if the issue already has a different type of relationship
        if has_existing_relationship?(issue, related_issue)
          Rails.logger.info("Skipped due to existing relationship: ##{issue.id} -> ##{related_issue.id}")
          next
        end

        # Create the relation and handle any errors
        begin
          IssueRelation.create!(issue_from: issue, issue_to: related_issue, relation_type: 'relates')
          Rails.logger.info("Related issue ##{issue.id} to issue ##{related_issue.id}")
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error("Failed to relate issue ##{issue.id} to issue ##{related_issue.id}: #{e.message}")
        end
      end
    end

    private

    # Extracts issue IDs from text (supports #123 and ##123)
    def extract_issue_ids(text)
      return [] if text.blank?

      text.scan(/##?(\d+)/).flatten.map(&:to_i) # Matches both #123 and ##123
    end

    # Checks for circular dependencies between issues
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

    # Checks if a different type of relationship already exists between issues
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
end
