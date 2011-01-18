Feature: Submit jobs
  As a user
  I want to submit a job
  In order to get computation done

  Scenario: command job submission successful
    When I submit a "date" command job
    Then the job status should be "submitted"
    And the job list should not be empty
