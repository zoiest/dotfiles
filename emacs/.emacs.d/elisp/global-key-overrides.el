;;; global-key-overrides.el --- Keys that win over every major and minor mode -*- lexical-binding: t; -*-

;; `global-set-key' puts a binding in the global map, which Emacs consults
;; *last*. Any major or minor mode binding the same key therefore shadows it.
;; The fast-motion keys were affected in plenty of modes:
;;
;;   comint-mode / shell / eshell   M-n, M-p  -> input history
;;   compilation-mode, grep-mode    M-n, M-p  -> next/previous error
;;   diff-mode                      M-n, M-p  -> next/previous hunk
;;   Info-mode                      M-n       -> clone-buffer
;;
;; To win everywhere, the bindings live in a minor mode keymap that is
;; registered in `emulation-mode-map-alists'. Emacs checks that list before
;; `minor-mode-map-alist' and before the major mode's local map, so these
;; bindings take precedence over both.
;;
;; Two deliberate exceptions remain:
;;
;;   - The minibuffer, where M-n / M-p are history navigation and "move 5
;;     lines" is meaningless. Overriding them there would also break
;;     `search-prompt-word-at-point'.
;;   - isearch, which installs `isearch-mode-map' as an
;;     `overriding-terminal-local-map'. That outranks even emulation maps, so
;;     M-n / M-p keep their isearch meaning while a search is active.

(defcustom my-fast-move-lines 5
  "Number of lines the fast-motion keys move."
  :type 'integer
  :group 'convenience)

(defcustom my-override-keys-exempt-modes nil
  "Major modes that should NOT get the overriding bindings.
Modes derived from these are exempt too. For example, to give comint
buffers their input history back:

  (setq my-override-keys-exempt-modes \\='(comint-mode))"
  :type '(repeat symbol)
  :group 'convenience)

;; `line-move' is what `next-line' calls internally. Using it keeps the goal
;; column behaviour while avoiding the byte-compiler's "`next-line' is for
;; interactive use only" warning.
(defun my-fast-move-down ()
  "Move point down `my-fast-move-lines' lines."
  (interactive)
  (line-move my-fast-move-lines))

(defun my-fast-move-up ()
  "Move point up `my-fast-move-lines' lines."
  (interactive)
  (line-move (- my-fast-move-lines)))

(defvar my-override-keys-map
  (let ((map (make-sparse-keymap)))
    (dolist (binding '(("M-n"      . my-fast-move-down)
                       ("M-p"      . my-fast-move-up)
                       ("M-<down>" . my-fast-move-down)
                       ("M-<up>"   . my-fast-move-up)))
      (define-key map (kbd (car binding)) (cdr binding)))
    map)
  "Keymap for `my-override-keys-mode'.")

(define-minor-mode my-override-keys-mode
  "Minor mode holding keybindings that override all other keymaps."
  :init-value nil
  :lighter nil
  :keymap my-override-keys-map)

(defun my-override-keys--maybe-enable ()
  "Enable `my-override-keys-mode' unless this buffer is exempt."
  (unless (or (minibufferp)
              (and my-override-keys-exempt-modes
                   (apply #'derived-mode-p my-override-keys-exempt-modes)))
    (my-override-keys-mode 1)))

(define-globalized-minor-mode my-override-keys-global-mode
  my-override-keys-mode my-override-keys--maybe-enable
  :group 'convenience)

(my-override-keys-global-mode 1)

;; This is what actually gives the map precedence over major and minor mode
;; maps; `define-minor-mode' alone would only reach `minor-mode-map-alist'.
(add-to-list 'emulation-mode-map-alists
             `((my-override-keys-mode . ,my-override-keys-map)))

(provide 'global-key-overrides)
