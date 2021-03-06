;; vlc.el - VLC interface for emacs
;; Copyright (C) 2017 Valts Liepiņš <valts@tase.lv>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

(defun vlc-get-process ()
  "Find or start a vlc process"
  (let ((process (get-process "vlc")))
    (if process
        process
      (let ((vlc-process (start-process "vlc" "*vlc*" "rvlc"
                                        "--no-video"
                                        ; Give plenty of buffer space
                                        "--network-caching" "10000")))
        (accept-process-output vlc-process)
        vlc-process))))

(defun vlc-play-track (track)
  "Play the TRACK"
  (process-send-string (vlc-get-process)
                       (format "add %s\n" track)))

(defun vlc-enqueue-track (track)
  "Enqueue the TRACK"
  (process-send-string (vlc-get-process)
                       (format "enqueue %s\n" track)))

(defun vlc-is-playing ()
  "Retrieve VLC play state"
  (let ((vlc-process (vlc-get-process)))
    (process-send-string vlc-process "is_playing\n")
    ;; Wait for output
    (accept-process-output vlc-process)
    (with-current-buffer (process-buffer vlc-process)
      (goto-char (point-max))
      (search-backward-regexp "\\([[:digit:]]\\)")
      (string-equal (match-string 1) "1"))))

(defun vlc-parse-playlist-item(item &optional id)
  "Parse ITEM and return alist with song metadata. Optionally take playlist item's ID."
  (if (string-match "\\(.+\\) - \\(.+\\) (\\(.+\\)) \\[played \\(.+\\) times?\\]" item)
      (list (cons 'raw-title item)
            (cons 'author (match-string 1 item))
            (cons 'title (match-string 2 item))
            (cons 'duration (match-string 3 item))
            (cons 'play-count (match-string 4 item)))
    (list (cons 'raw-title item))))

(defun vlc-get-playlist ()
  (let ((vlc-process (vlc-get-process)))
    (process-send-string vlc-process "playlist\n")
    ;; Wait for output
    (accept-process-output vlc-process)
    (with-current-buffer (process-buffer vlc-process)
      (goto-char (point-max))
      ;; Find the beginning of playlist
      (search-backward "- Playlist")
      (loop do (search-forward-regexp "\\([[:digit:]]+\\) - \\([^[:cntrl:]]+\\)")
            until (equal (match-string 2) "Media Library")
            collect (vlc-parse-playlist-item (match-string 2) (match-string 1))))))
