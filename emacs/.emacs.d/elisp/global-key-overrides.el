;;; global-key-overrides.el --- M-arrow navigation that overrides every mode -*- lexical-binding: t; -*-

;; Navigation on the M-<arrow> cluster, overriding every major and minor mode
;; so the keys mean the same thing everywhere:
;;
;;   M-<up>    / M-<down>    move `my-fast-move-lines' lines
;;   M-<left>  / M-<right>   move a word, same as M-b / M-f
;;
;; `global-set-key' is not enough: it writes to the global map, which Emacs
;; consults *last*, so any mode binding the same key shadows it. These keys
;; therefore live in a minor mode keymap registered in
;; `emulation-mode-map-alists', a list Emacs checks before
;; `minor-mode-map-alist' and before the major mode's local map.
;; (`define-minor-mode' alone would only reach `minor-mode-map-alist' and
;; would still lose to major modes.)
;;
;; Mode bindings that the arrows displace, and their surviving alternatives:
;;
;;   org-mode   M-<left>/M-<right> -> org-metaleft / org-metaright
;;              (promote/demote, also on C-c C-x l and C-c C-x r)
;;
;; M-n / M-p are deliberately left alone: they keep whatever each mode gives
;; them (comint input history, compilation next/previous error, diff hunk
;; motion, Info clone-buffer), so there is no mixed behaviour to remember.
;;
;; Two deliberate exceptions remain:
;;
;;   - The minibuffer, where vertical motion is meaningless. Enabling the
;;     mode there would also interfere with `search-prompt-word-at-point'.
;;   - isearch, which installs `isearch-mode-map' as an
;;     `overriding-terminal-local-map'. That outranks even emulation maps.

(defcustom my-fast-move-lines 5
  "Number of lines the fast-motion keys move."
  :type 'integer
  :group 'convenience)

(defcustom my-override-keys-exempt-modes nil
  "Major modes where the M-<arrow> navigation keys should NOT override.
Modes derived from these are exempt too.  For example, to let org-mode
keep M-<left> / M-<right> for promoting and demoting:

  (setq my-override-keys-exempt-modes \\='(org-mode))"
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
    ;; `forward-word' / `backward-word' are exactly what M-f / M-b run, so
    ;; the arrows match them. Binding the commands (rather than copying
    ;; M-f's binding) also keeps any mode's [remap forward-word] working.
    (dolist (binding '(("M-<down>"  . my-fast-move-down)
                       ("M-<up>"    . my-fast-move-up)
                       ("M-<right>" . forward-word)
                       ("M-<left>"  . backward-word)))
      (define-key map (kbd (car binding)) (cdr binding)))
    map)
  "Keymap for `my-override-keys-mode'.
Holds the M-<arrow> navigation keys, which must beat every other keymap.")

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
