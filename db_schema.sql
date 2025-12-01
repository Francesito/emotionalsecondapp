-- Esquema MySQL para la app de ánimo escolar.
-- Pensado para levantarse en Aiven; usa InnoDB y utf8mb4.

CREATE DATABASE IF NOT EXISTS defaultdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE defaultdb;

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  role ENUM('student','tutor') NOT NULL,
  name VARCHAR(120) NOT NULL,
  matricula VARCHAR(50) NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB;

CREATE TABLE `groups` (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(120) NOT NULL,
  tutor_id BIGINT UNSIGNED NOT NULL,
  term VARCHAR(20) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_groups_tutor FOREIGN KEY (tutor_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE group_members (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  group_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  term VARCHAR(20) NOT NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_group_student UNIQUE (group_id, student_id, term),
  CONSTRAINT fk_members_group FOREIGN KEY (group_id) REFERENCES `groups`(id),
  CONSTRAINT fk_members_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE mood_logs (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  logged_date DATE NOT NULL,
  mood ENUM('muyBien','bien','neutral','mal','muyMal') NOT NULL,
  note VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_mood_day UNIQUE (student_id, logged_date),
  CONSTRAINT fk_mood_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE weekly_perceptions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  subject VARCHAR(120) NOT NULL,
  week_start DATE NOT NULL,
  emotion ENUM('muyBien','bien','neutral','mal','muyMal') NOT NULL,
  notes VARCHAR(255) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT uq_perception UNIQUE (student_id, subject, week_start),
  CONSTRAINT fk_perception_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE justifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  group_id BIGINT UNSIGNED NULL,
  type VARCHAR(100) NOT NULL,
  evidence_url VARCHAR(255) NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  reviewer_id BIGINT UNSIGNED NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_just_student FOREIGN KEY (student_id) REFERENCES users(id),
  CONSTRAINT fk_just_group FOREIGN KEY (group_id) REFERENCES `groups`(id),
  CONSTRAINT fk_just_reviewer FOREIGN KEY (reviewer_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE alerts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  type ENUM('mood','attendance','grade') NOT NULL,
  severity ENUM('low','medium','high') NOT NULL,
  message VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  seen_at DATETIME NULL,
  PRIMARY KEY (id),
  INDEX idx_alert_student (student_id),
  CONSTRAINT fk_alert_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_user_id BIGINT UNSIGNED NOT NULL,
  to_user_id BIGINT UNSIGNED NULL,
  group_id BIGINT UNSIGNED NULL,
  body TEXT NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_msg_group (group_id),
  INDEX idx_msg_pair (from_user_id, to_user_id),
  CONSTRAINT fk_msg_from FOREIGN KEY (from_user_id) REFERENCES users(id),
  CONSTRAINT fk_msg_to FOREIGN KEY (to_user_id) REFERENCES users(id),
  CONSTRAINT fk_msg_group FOREIGN KEY (group_id) REFERENCES `groups`(id)
) ENGINE=InnoDB;

CREATE TABLE attendance_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  event_date DATE NOT NULL,
  status ENUM('present','absent','late') NOT NULL,
  notes VARCHAR(255) NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_att_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE grade_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  student_id BIGINT UNSIGNED NOT NULL,
  subject VARCHAR(120) NOT NULL,
  score DECIMAL(5,2) NOT NULL,
  max_score DECIMAL(5,2) NOT NULL DEFAULT 100,
  recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT fk_grade_student FOREIGN KEY (student_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- Vista simple para saber cuántos justificantes tiene un alumno en el término actual.
CREATE OR REPLACE VIEW v_justifications_term AS
SELECT
  student_id,
  DATE_FORMAT(created_at, '%Y') AS year,
  IF(MONTH(created_at) <= 6, 'T1', 'T2') AS term_label,
  COUNT(*) AS total
FROM justifications
GROUP BY student_id, year, term_label;
