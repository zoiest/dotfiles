;;; global-mark-navigation.el --- VS Code-like go back/forward navigation -*- lexical-binding: t; -*-

;; A linear navigation history with a cursor index.
;; - "Go back" moves earlier in history
;; - "Go forward" moves later in history
;; - New jumps truncate forward history (like a browser)
;; - Significant movements auto-push to history

(defvar my-nav-history '() "List of markers representing navigation history.")
(defvar my-nav-index -1 "Current position in navigation history.")
(defvar my-nav-max 100 "Maximum history size.")
(defvar my-nav--skip-tracking nil "Skip post-command tracking for this command cycle.")
(defvar my-nav--last-point nil "Last known point for detecting large jumps.")
(defvar my-nav--last-buffer nil "Last known buffer for detecting buffer switches.")
(defvar my-nav-distance-threshold 20 "Minimum line distance to count as a significant jump.")

;; --- Results buffers are never recorded in the history ---

;; Clicking or moving around in *compilation*, *xref*, *grep*, or *rg*
;; should not leave entries in the navigation history: those positions
;; are not places you want `my-nav-go-back' to return to. Matching on
;; major mode (rather than buffer name) also covers renamed buffers such
;; as *compilation*<2>, and `grep-mode' / `rg-mode', which both derive
;; from `compilation-mode'.
;;
;; Only the marker's own buffer is checked, so moving *into* a results
;; buffer still records where you came from. That is what makes the
;; quickfix round trip work: edit foo.c, click into *compilation* (pushes
;; foo.c), select a match to land in bar.c, then `my-nav-go-back' returns
;; to foo.c rather than to the *compilation* buffer.
(defvar my-nav-excluded-modes '(compilation-mode xref--xref-buffer-mode)
  "Major modes whose positions are never pushed onto `my-nav-history'.")

(defun my-nav--excluded-buffer-p (buffer)
  "Non-nil if BUFFER's positions should be kept out of the history."
  (and (buffer-live-p buffer)
       (with-current-buffer buffer
         (or (apply #'derived-mode-p my-nav-excluded-modes)
             ;; Shared list from results-buffer-origin.el, when loaded.
             (and (boundp 'my-results-buffer-names)
                  (member (buffer-name buffer) my-results-buffer-names)
                  t)))))

(defun my-nav--push-marker (marker)
  "Push MARKER onto navigation history, truncating forward history."
  ;; Skip results buffers (*compilation*, *xref*, *grep*, *rg*).
  (unless (my-nav--excluded-buffer-p (marker-buffer marker))
    ;; Don't push duplicates
    (unless (and (> (length my-nav-history) 0)
                 (>= my-nav-index 0)
                 (let ((top (nth my-nav-index my-nav-history)))
                   (and (marker-buffer top)
                        (eq (marker-buffer top) (marker-buffer marker))
                        (= (marker-position top) (marker-position marker)))))
      ;; Truncate forward history
      (when (< my-nav-index (1- (length my-nav-history)))
        (setq my-nav-history (seq-take my-nav-history (1+ my-nav-index))))
      ;; Push new marker
      (setq my-nav-history (append my-nav-history (list marker)))
      ;; Trim if too long
      (when (> (length my-nav-history) my-nav-max)
        (setq my-nav-history (seq-drop my-nav-history 1)))
      (setq my-nav-index (1- (length my-nav-history))))))

(defun my-nav-push ()
  "Push current position onto navigation history."
  (interactive)
  (my-nav--push-marker (point-marker)))

(defun my-nav-go-back ()
  "Go back in navigation history."
  (interactive)
  (setq my-nav--skip-tracking t)
  (if (or (null my-nav-history) (<= my-nav-index 0))
      (message "No earlier position in history")
    ;; If at the head, push current position so we can come forward to it
    (when (= my-nav-index (1- (length my-nav-history)))
      (my-nav--push-marker (point-marker)))
    (setq my-nav-index (1- my-nav-index))
    (my-nav--goto (nth my-nav-index my-nav-history))))

(defun my-nav-go-forward ()
  "Go forward in navigation history."
  (interactive)
  (setq my-nav--skip-tracking t)
  (if (or (null my-nav-history)
          (>= my-nav-index (1- (length my-nav-history))))
      (message "No later position in history")
    (setq my-nav-index (1+ my-nav-index))
    (my-nav--goto (nth my-nav-index my-nav-history))))

(defun my-nav--goto (marker)
  "Jump to MARKER."
  (when (and marker (marker-buffer marker))
    (switch-to-buffer (marker-buffer marker))
    (goto-char (marker-position marker))))

;; --- Auto-push on significant movements ---

(defun my-nav--post-command ()
  "Track position changes after each command; push on significant jumps."
  (if my-nav--skip-tracking
      ;; Reset tracking state to current position (don't detect the nav jump as a movement)
      (progn
        (setq my-nav--skip-tracking nil)
        (setq my-nav--last-point (point)
              my-nav--last-buffer (current-buffer)))
    ;; Normal tracking
    (let ((buf (current-buffer))
          (pt (point)))
      (when (and my-nav--last-buffer
                 (or
                  ;; Buffer changed
                  (not (eq buf my-nav--last-buffer))
                  ;; Large line distance in same buffer
                  (and my-nav--last-point
                       (eq buf my-nav--last-buffer)
                       (> (abs (- (line-number-at-pos pt)
                                  (line-number-at-pos my-nav--last-point)))
                          my-nav-distance-threshold))))
        ;; Push the previous position
        (when (buffer-live-p my-nav--last-buffer)
          (let ((marker (make-marker)))
            (set-marker marker (or my-nav--last-point (point-min)) my-nav--last-buffer)
            (my-nav--push-marker marker))))
      (setq my-nav--last-point pt
            my-nav--last-buffer buf))))

(add-hook 'post-command-hook #'my-nav--post-command)

;; --- Push before xref and other jump commands ---

(defun my-nav-push-before-jump (&rest _)
  "Push current position before a jump command."
  (unless my-nav--skip-tracking
    (my-nav-push)))

(advice-add 'xref-find-definitions :before #'my-nav-push-before-jump)
(advice-add 'xref-find-references :before #'my-nav-push-before-jump)
(advice-add 'xref-goto-xref :before #'my-nav-push-before-jump)
(advice-add 'imenu :before #'my-nav-push-before-jump)
(advice-add 'beginning-of-buffer :before #'my-nav-push-before-jump)
(advice-add 'end-of-buffer :before #'my-nav-push-before-jump)

;; Keybindings: C-o/C-i for navigation, move defaults to C-c o/C-c i
(global-set-key (kbd "C-o") #'my-nav-go-back)
(global-set-key (kbd "C-i") #'my-nav-go-forward)
(global-set-key (kbd "C-c o") #'open-line)
(global-set-key (kbd "C-c i") #'indent-for-tab-command)

(provide 'global-mark-navigation)
