;;; display-buffer-configurations.el --- Display buffer rules -*- lexical-binding: t; -*-

;; display buffer related configurations

(defun toggle-window-dedicated ()
  "Control whether or not Emacs is allowed to display another
buffer in current window."
  (interactive)
  (message
   (if (let ((window (get-buffer-window (current-buffer))))
         ; set-window-dedicated-p returns FLAG that was passed as
         ; second argument, thus can be used as COND for if:
         (set-window-dedicated-p window (not (window-dedicated-p window))))
       "%s: Can't touch this!"
     "%s is up for grabs.")
   (current-buffer)))

;; decide how different kind of buffers get popped up
(add-to-list 'display-buffer-alist
             '("\\*e?shell\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . -1) ;; -1 == L  0 == Mid 1 == R
               (window-height . 0.33) ;; take 2/3 on bottom left
               (window-parameters
                (no-delete-other-windows . nil))))

(add-to-list 'display-buffer-alist
             '("\\*\\(grep\\|scratch\\|xref\\|compilation\\|rg\\)\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 0)
               (window-height . 0.33)
               (window-parameters
                (no-delete-other-windows . nil))))

(add-to-list 'display-buffer-alist
             '("\\*\\([Hh]elp\\|Backtrace\\|Compile-[Ll]og\\|Warnings\\|Messages\\|Command History\\|command-log\\)\\*"
               (display-buffer-in-side-window)
               (side . right)
               (slot . 0)
               (window-width . 80)
               (window-parameters
                (no-delete-other-windows . nil))))

(add-to-list 'display-buffer-alist
             '("\\*TeX errors\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 3)
               (window-height . shrink-window-if-larger-than-buffer)
               (dedicated . t)))

(add-to-list 'display-buffer-alist
             '("\\*TeX Help\\*"
               (display-buffer-in-side-window)
               (side . bottom)
               (slot . 4)
               (window-height . shrink-window-if-larger-than-buffer)
               (dedicated . t)))

;; https://emacs.stackexchange.com/a/40517 <- make splitting sensibly
;; prefer two horizontal split buffers

(defun split-window-sensibly-prefer-horizontal (&optional window)
"Based on `split-window-sensibly', but prefers to split WINDOW side-by-side."
  (let ((window (or window (selected-window))))
    (or (and (window-splittable-p window t)
         ;; Split window horizontally
         (with-selected-window window
           (split-window-right)))
    (and (window-splittable-p window)
         ;; Split window vertically
         (with-selected-window window
           (split-window-below)))
    (and
         ;; If WINDOW is the only usable window on its frame (it is
         ;; the only one or, not being the only one, all the other
         ;; ones are dedicated) and is not the minibuffer window, try
         ;; to split it horizontally disregarding the value of
         ;; `split-height-threshold'.
         (let ((frame (window-frame window)))
           (or
            (eq window (frame-root-window frame))
            (catch 'done
              (walk-window-tree (lambda (w)
                                  (unless (or (eq w window)
                                              (window-dedicated-p w))
                                    (throw 'done nil)))
                                frame)
              t)))
     (not (window-minibuffer-p window))
     (let ((split-width-threshold 0))
       (when (window-splittable-p window t)
         (with-selected-window window
               (split-window-right))))))))

(defun split-window-really-sensibly (&optional window)
  (let ((window (or window (selected-window))))
    (if (> (window-total-width window) (* 2 (window-total-height window)))
        (with-selected-window window (split-window-sensibly-prefer-horizontal window))
      (with-selected-window window (split-window-sensibly window)))))

(setq split-window-preferred-function 'split-window-really-sensibly)

;; stop emacs from splitting the window
(setq split-height-threshold nil
      split-width-threshold nil)

;; move focus on new splittig window
(global-set-key "\C-x2" (lambda () (interactive)(split-window-vertically) (other-window 1)))
(global-set-key "\C-x3" (lambda () (interactive)(split-window-horizontally) (other-window 1)))

(provide 'display-buffer-configurations)
