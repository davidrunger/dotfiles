# frozen_string_literal: true

class Runner
  include FactoryBot::Syntax::Methods

  def run
    touch_user_sign_in_timestamps
    update_passwords
    unabbreviate_names
    dismiss_questionnaire
    add_students_to_rosters
    unpublish_announcements
    set_up_for_canvas
    set_nina_cruz_canvas_user_id
  end

  private

  # This is how we ensure that the users show in #su (defined in z.rb).
  def touch_user_sign_in_timestamps
    %w[
      davidrunger
      davidrunger1
      ninacruz10
    ].each do |login|
      ube(login).update!(current_sign_in_at: Time.current)
    end
  end

  def update_passwords
    update_password!("jackdawson@cl.org")
    update_password!("david.runger@commonlit.org")
    update_password!("dsdemo@cl-test.org")
  end

  def unabbreviate_names
    # This makes it so that smoke tests can find these users.
    [
      "Valerie Frizzle",
      "Lindsay Funke",
      "Greg Pikitis",
      "Shauna Malwae-Tweep",
      "Charlie Kelly",
    ].each do |full_name|
      first_name, *last_name_parts = full_name.split(" ")
      last_name = last_name_parts.join(" ")

      PersonProfile.where(first_name:, last_name: "#{last_name[0]}.").find_each do |person_profile|
        person_profile.update!(last_name:)
      end
    end
  end

  def dismiss_questionnaire
    # Dismiss questionnaire for all people who have logged in after July 1.
    Person.
      joins(:active_user).
      where("users.current_sign_in_at > ?", Time.new(2023, 7, 1).in_time_zone).
      distinct.
      pluck(:id).each do |person_id|
        FeatureDismissal.create!(
          person_id:,
          feature_name: FeatureDismissal::TEACHER_QUESTIONNAIRE,
        )
        FeatureDismissal.create!(
          person_id:,
          feature_name: FeatureDismissal::SCHOOL_CONFIRMATION,
        )
      end
  end

  def add_students_to_rosters
    # Put one student per grade in my class and one of Jack Dawson's classes.
    my_roster = tme.person.primary_rosters.first
    jack_person = User.find_by!(email: "jackdawson@cl.org").person
    jacks_roster =
      create(
        :roster,
        name: "Rainbows",
        primary_faculty_membership: jack_person.faculty_memberships.active.verified.first!,
        grades: [Grade.find_by!(grade: 9)],
        subjects: [Subject.find_by!(subject: Subject::ELA)],
      )

    my_roster.roster_members.with_deleted.find_each(&:destroy!)

    letters = ("A".."Z").to_a

    User.
      find_each.
      select(&:student?).
      reject(&:blocked?).
      first(10).
      sort_by(&:last_name).
      each.
      with_index do |user, index|
        person = user.person
        ensure_in_roster(my_roster, person)
        ensure_in_roster(jacks_roster, person)
        profile = person.person_profile
        profile.grade_year_unlocked = true
        profile.update!(grade_year: index + 3, last_name: "#{letters[index]}.")
      end
  end

  def unpublish_announcements
    Announcement.where.not(published_at: nil).find_each { _1.update!(published_at: nil) }
  end

  def set_up_for_canvas
    Roster.
      where(
        canvas_roster_url: "https://commonlit.instructure.com/api/lti/courses/315/names_and_roles",
      ).
      find_each { _1.update!(canvas_roster_url: nil) }

    roster = Roster.find_by!(code: "WM4FEFRF")
    ensure_in_roster(roster, sme.person)
    params = ActionController::Parameters.new(
      {
        "activity_subset" => 1,
        "annotation_task" => "<strong><span style=\"font-size:18pt;\">Today you'll read \"MVP\" and practice finding the meaning of unknown words.</span></strong><br><br><strong><span style=\"font-size:18pt;\">Today's Agenda:</span></strong><br><br><span style=\"font-size:18pt;\">Part 1 - Warm-Up: Writing</span><br><span style=\"font-size:18pt;\">Part 2 - Video Introducing the Target Skill: Unknown Words</span><br><span style=\"font-size:18pt;\">Part 3 - Review the Target Skill</span><br><span style=\"font-size:18pt;\">Part 4 - Reading and Answering Questions</span><br><span style=\"font-size:18pt;\">Part 5 - Assessment</span><br><br><span style=\"font-size:10pt;\"><em>See image and media license details <a href=\"https://docs.google.com/document/d/1r2ijtsuKHhCEgoLPW0odMLTgqE6LUMnqQDxegBe0sIM/copy\" target=\"_blank\" rel=\"noopener\">here</a>.</em></span>",
        "class_student_pairs" => [],
        "due_date" => "2050-10-14",
        "enable_reading_modalities" => false,
        "guided_reading_mode_roster_student_pairs" => [],
        "guided_reading_mode_type" => "whole_class_guided_reading_mode",
        "has_grm_for_any_student" => false,
        "lesson_template_id" => 8725,
        "lesson_type" => "whole_class",
        "require_question_completion" => true,
        "roster_ids" => [
          6546137,
        ],
        "secondary_teacher_ids" => [],
        "selected_school_id" => 513516,
        "start_date" => "2023-10-10",
        "unit_id" => 0,
        "locale" => "en",
        "format" => :json,
        "controller" => "api/v1/teachers/lessons",
        "action" => "create",
        "lesson" => {
          "lesson_template_id" => 8725,
          "annotation_task" => "<strong><span style=\"font-size:18pt;\">Today you'll read \"MVP\" and practice finding the meaning of unknown words.</span></strong><br><br><strong><span style=\"font-size:18pt;\">Today's Agenda:</span></strong><br><br><span style=\"font-size:18pt;\">Part 1 - Warm-Up: Writing</span><br><span style=\"font-size:18pt;\">Part 2 - Video Introducing the Target Skill: Unknown Words</span><br><span style=\"font-size:18pt;\">Part 3 - Review the Target Skill</span><br><span style=\"font-size:18pt;\">Part 4 - Reading and Answering Questions</span><br><span style=\"font-size:18pt;\">Part 5 - Assessment</span><br><br><span style=\"font-size:10pt;\"><em>See image and media license details <a href=\"https://docs.google.com/document/d/1r2ijtsuKHhCEgoLPW0odMLTgqE6LUMnqQDxegBe0sIM/copy\" target=\"_blank\" rel=\"noopener\">here</a>.</em></span>",
          "enable_reading_modalities" => false,
          "require_question_completion" => true,
          "unit_id" => 0,
        },
      },
    )
    user = ube("nina.cruz@cl-test.org")
    form = LessonForm.new(params, user)

    def Lesson.create!(attributes)
      super(attributes.merge(id: 15497045))
    end

    lesson = Lessons::Create.new(roster, form).process
    CreateStudentLessonsWorker.new.perform(lesson.id)
  end

  def set_nina_cruz_canvas_user_id
    nina_cruz_canvas_user_id = "60e90db7-4e1c-4534-b5ae-df897dfd7931"

    User.where(canvas_user_id: nina_cruz_canvas_user_id).find_each do |user|
      user.update!(canvas_user_id: nil)
    end

    ube("ninacruz10").update!(canvas_user_id: nina_cruz_canvas_user_id)
  end

  def ensure_in_roster(roster, person)
    existing_member = roster.reload.roster_members.with_deleted.manual.find_by(person:)
    if existing_member&.deleted_at?
      existing_member.update!(deleted_at: nil)
    else
      roster.roster_members.manual.new(person:).save!
    end
  end

  def update_password!(email)
    User.find_by!(email:).update!(password: ENV.fetch("USER_PASSWORD"))
  end
end

Runner.new.run
