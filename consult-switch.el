;; consult-file-jump.el --- consult file utils -*- lexical-binding: t -*-

(eval-when-compile
  (require 'cl-lib)
  (require 'subr-x))
(require 'bookmark)
(require 'project)
(require 'consult)

(defcustom consult-switch-shadow-filenames t
  "Shadow file names instead of replacing them when using
`consult-insert-user-directory'."
  :type 'boolean)

(defun consult--directory-bookmarks ()
  "Return bookmarks that are directories."
  (bookmark-maybe-load-default-file)
  (let ((file-narrow ?f))
    (thread-last bookmark-alist
      (cl-remove-if-not (lambda (cand)
                          (let ((bm (bookmark-get-bookmark-record cand)))
                            (when-let ((file (alist-get 'filename bm)))
                              (file-directory-p file)))))
      (mapcar (lambda (cand) (let ((bm (bookmark-get-bookmark-record cand)))
                          (propertize (car cand) 'consult--type file-narrow)))))))

(defun consult--user-directory (&optional prompt dir)
  "Return a directory chosen from bookmarks and projects."
  (or dir
      (let ((match (or dir
                       (consult--multi
                        `((:name "(b)ookmarks"
                                 :narrow 98
                                 :category bookmark
                                 :face consult-file
                                 :history bookmark-history
                                 ;; :action ,#'bookmark-locate
                                 :items ,#'consult--directory-bookmarks
                                 :default t)
                          (:name "( )This directory"
                                 :narrow 32
                                 :category file
                                 :face consult-file
                                 ;; :action ,(lambda (this-dir &optional norecord)
                                 ;;            (insert (abbreviate-file-name default-directory)))
                                 :items (,(abbreviate-file-name default-directory)))
                          (:name "(p)rojects"
                                 :narrow ?p
                                 :category file
                                 :face consult-file
                                 :history nil
                                 ;; :action ,(lambda (project-dir &optional norecord)
                                 ;;            (insert project-dir))
                                 :items ,(lambda () (mapcar 'car project--list))))
                        :prompt (or prompt "Switch directory: ")
                        :sort nil))))
        (pcase (plist-get (cdr match) :category)
          ('bookmark (bookmark-get-filename (car match)))
          ('file (car match))))))

;;;###autoload
(defun find-file-in-directory (dir &optional wildcards)
  (interactive (list (consult--user-directory "In directory: ")))
  (let ((default-directory dir))
    (call-interactively #'find-file)))
  
;;;###autoload
(defun consult-find-from-jump-directory (&optional arg)
  "Jump to file from the current minibuffer directory."
  (interactive "P")
  (let* ((shadow-pt (overlay-end rfn-eshadow-overlay))
         (mc (substring-no-properties
              (minibuffer-contents)
              (if shadow-pt
                  (- shadow-pt (minibuffer-prompt-end)) 0)))
         (dir (file-name-directory mc))
         (search (file-name-nondirectory mc)))
    (run-at-time 0 nil
                 (lambda () (consult-find
                        dir
                        (concat search
                                (unless (string-empty-p search)
                                  (plist-get (consult--async-split-style)
                                             :initial))))))
    (abort-recursive-edit)))
  
;;;###autoload
(defun consult-insert-user-directory ()
    "Choose a directory from bookmarks and projects with
completion and insert it at point."
    (interactive)
    (let* ((file-name (file-name-nondirectory (minibuffer-contents)))
           (new-dir (consult--user-directory))
           (new-full-name (concat (file-name-as-directory new-dir)
                                  file-name)))
      (when new-dir
        (if consult-switch-shadow-filenames
            (insert (concat "/" new-full-name))
          (delete-minibuffer-contents)
          (insert new-full-name)))))

(provide 'consult-switch)