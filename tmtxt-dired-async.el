;;; tmtxt-dired-async.el --- Asynchoronous execution library for Emacs Dired -*- lexical-binding: t -*-

;; Author: Trần Xuân Trường
;; Maintainer: Trần Xuân Trường
;; Version: 0.1
;; Package-Requires: (tmtxt-async-tasks)
;; Homepage: https://truongtx.me/tmtxt-dired-async.html
;; Keywords: dired, asynchoronous, rsync

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.


;;; Commentary:

;; A library for Emacs Dired mode to copy, compress, decompress files
;; asynchronously.  It also provides the ability to mark files in multiple
;; directories and then copy all of them into a destination library.  This
;; library is designed for Unix-based system like MacOS, Ubuntu,… The reason why
;; I developed this library is to overcome Emacs Dired’s drawbacks.  Everytime I
;; need to copy, move, compress, uncompress,… big files, Emacs is blocked until
;; those processes finish execution.  That’s really annoying.  This extension
;; helps solve that problem by providing Emacs with the ability to
;; asynchronously execute those tasks as well as display the output to the user.

;;; Code:

;; TODO: stick the output window with the result buffer
;; using dedicated window
;; TODO: shortcut keys for close the result window
;; TODO: check process exit status, if not success, not close the result window
;; TODO: undo function

;; ----------------------------------------------
;; ----------------------------------------------

;; required for dired-dwim-target-directory
(require 'dired-aux)
(require 'tmtxt-async-tasks)

;; get file size
(defvar tda/get-files-size-command "du"
  "The name of \"du\" command (or the path to the \"du\" command).")
(defvar tda/get-files-size-arguments "-hc"
  "The arguments for passing into the \"du\" command.")

;; get file size
(defun tda/get-files-size ()
  "Calculate files size for all the marked files."
  (interactive)
  (let ((files (dired-get-marked-files)) command)
	;; the get files size command
	(setq command tda/get-files-size-command)
	(setq command (concat command " " tda/get-files-size-arguments " "))
	;; add selected file names as arguments to the command
	(dolist (file files)
	  (setq command (concat command (shell-quote-argument file) " ")))
	;; execute the command
	(tat/execute-async command "file size")))

;; ----------------------------------------------
;; ----------------------------------------------
;; Async Rsync
(defvar tda/rsync-command-name "rsync"
  "The name of rsync command (or the path to the rsync command).")
(defvar tda/rsync-arguments "-avz --progress"
  "The arguments for passing into the rsync command.")

(defun cpb/maybe-convert-directory-to-rsync-target (directory)
  "If directory starts with /scp: or /ssh: it is probably a tramp
target and should be converted to rsync-compatible destination
string, else we do (shell-quote-argument (expand-file-name
directory)) as is required for normal local targets acquired with
read-file-name and dired-dwim-target-directory."
  (if (or (string-prefix-p "/scp:" directory)
          (string-prefix-p "/ssh:" directory))
      ;; - throw out the initial "/scp:" or "/ssh:"
      ;; - replace spaces with escaped spaces
      ;; - surround the whole thing with quotes
      ;; TODO: double-check that target ends with "/""
      ;; which in the case of DWIM is what we want
      (prin1-to-string
       (replace-regexp-in-string "[[:space:]]" "\\\\\\&"
                                 (substring directory 5)))
    ;; this is what tmtxt-dired-async usually does
    (shell-quote-argument (expand-file-name directory))))

(defun tda/rsync (dest)
  "Asynchronously copy file to DEST using Rsync for dired.

	This function runs only on Unix-based system.
	Usage: same as normal dired copy function."
  (interactive ;; offer dwim target as the suggestion
   (list (read-file-name "Rsync to:" (dired-dwim-target-directory))))
  (let ((files (dired-get-marked-files nil current-prefix-arg))
		command)
	;; the rsync command
	(setq command
		  (concat tda/rsync-command-name " " tda/rsync-arguments " "))
	;; add all selected file names as arguments to the rsync command
	(dolist (file files)
	  (setq command (concat command (shell-quote-argument file) " ")))
	;; append the destination to the rsync command
	(setq command (concat command (cpb/maybe-convert-directory-to-rsync-target dest)))
	;; execute the command asynchronously
	(tat/execute-async command "rsync")))

(defun tda/rsync-sudo (dest)
  "Asynchronously copy file to DEST using Rsync for dired.

	This function runs only on Unix-based system.
	Usage: same as normal dired copy function."
  (interactive ;; offer dwim target as the suggestion
   (list (read-file-name "Rsync to:" (dired-dwim-target-directory))))
  (let ((files (dired-get-marked-files nil current-prefix-arg))
		command)
	;; the rsync command
	(setq command
		  (concat "sudo " tda/rsync-command-name " " tda/rsync-arguments " "))
	;; add all selected file names as arguments to the rsync command
	(dolist (file files)
	  (setq command (concat command (shell-quote-argument file) " ")))
	;; append the destination to the rsync command
	(setq command (concat command (cpb/maybe-convert-directory-to-rsync-target dest)))
	;; execute the command asynchronously
	(tat/execute-async command "rsync")))

(defun tda/rsync-delete (dest)
  "Asynchronously copy file to DEST using Rsync for dired include the delete option.

	This function runs only on Unix-based system.
	Usage: same as normal dired copy function."
  (interactive ;; offer dwim target as the suggestion
   (list (read-file-name "Rsync delete to:" (dired-dwim-target-directory))))
  (let ((files (dired-get-marked-files nil current-prefix-arg))
		command)
	;; the rsync command
	(setq command
		  (concat tda/rsync-command-name " " tda/rsync-arguments " --delete "))
	;; add all selected file names as arguments to the rsync command
	(dolist (file files)
	  (setq command (concat command (shell-quote-argument file) " ")))
	;; append the destination to the rsync command
	(setq command (concat command (cpb/maybe-convert-directory-to-rsync-target dest)))
	;; execute the command asynchronously
	(tat/execute-async command "rsync")))

(defun tda/rsync-delete-sudo (dest)
  "Asynchronously copy file to DEST using Rsync for dired include the delete option.

	This function runs only on Unix-based system.
	Usage: same as normal dired copy function."
  (interactive ;; offer dwim target as the suggestion
   (list (read-file-name "Rsync delete to:" (dired-dwim-target-directory))))
  (let ((files (dired-get-marked-files nil current-prefix-arg))
		command)
	;; the rsync command
	(setq command
		  (concat "sudo " tda/rsync-command-name " " tda/rsync-arguments " --delete "))
	;; add all selected file names as arguments to the rsync command
	(dolist (file files)
	  (setq command (concat command (shell-quote-argument file) " ")))
	;; append the destination to the rsync command
	(setq command (concat command (cpb/maybe-convert-directory-to-rsync-target dest)))
	;; execute the command asynchronously
	(tat/execute-async command "rsync")))

;; ----------------------------------------------
;; ----------------------------------------------
;; async zip files
(defvar tda/zip-command "zip"
  "The command name (or the path to the zip command.")
(defvar tda/zip-arguments
  "-ru9" "The compression level for dired async zip command, from 0-9. This variable is a string, so if you change this value, please set it as a string.")

(defun tda/zip (output)
  "Asynchronously compress marked files to the output file."
  (interactive
   (list (expand-file-name (read-file-name "Add to file: "))))

  (let (command
		(files (dired-get-marked-files nil current-prefix-arg)))
	;; the zip command
	(setq command
		  (concat tda/zip-command " " tda/zip-arguments " "))
	;; append the output file
	(setq command
		  (concat command (shell-quote-argument output) " "))
	;; add all selected files as argument
	(dolist (file files)
	  (setq command
			(concat command
					(shell-quote-argument
					 (file-name-nondirectory file)) " ")))
	(message command)
	;; execute the command asynchronously
	(tat/execute-async command "zip")))

;; ----------------------------------------------
;; ----------------------------------------------
;; Uncompress function
(defvar tda/unzip-command "unzip"
  "The command name (or path to the unzip command).")
(defvar tda/unzip-arguments ""
  "The arguments for passing into the unzip command.")

(defun tda/unzip ()
  "Asynchronously decompress the zip file at point."
  (interactive)

  (let (command
		output-directory
		(file (dired-get-filename 'verbatim)))

	;; new directory name for the output files
	(setq output-directory
		  (file-name-sans-extension
		   (dired-get-filename 'verbatim)))

	;; the unzip command
	(setq command (concat tda/unzip-command " " tda/unzip-arguments " "))
	;; append the file name
	(setq command
		  (concat command
				  (shell-quote-argument file) " "))
	;; append the output directory name
	(setq command
		  (concat command "-d "
				  (shell-quote-argument output-directory)))

	;; execute the command asynchronously
	(tat/execute-async command "unzip")))

;; ----------------------------------------------
;; ----------------------------------------------
;; Rsync from multiple directories
(defvar tda/rsync-multiple-file-list
  () "The list of the files to be copied.")

(defun tda/rsync-multiple-mark-file ()
  "Add file to waiting list for copying."
  (interactive)
  ;; Add file to the list
  (add-to-list 'tda/rsync-multiple-file-list
			   (dired-get-filename))
  ;; Message for user
  (message
   (concat "File " (dired-get-filename 'verbatim) " added to waiting list.")))

(defun tda/rsync-multiple-empty-list ()
  "Empty the waiting list."
  (interactive)
  ;; Empty the list
  (setq tda/rsync-multiple-file-list '())
  ;; message for the user
  (message "Waiting list empty."))

(defun tda/rsync-multiple-remove-item ()
  "Remove the file at point from the waiting list if it is in."
  (interactive)
  (let ((file-to-remove (dired-get-filename)))
	;; remove the item from the list
	(setq tda/rsync-multiple-file-list
		  (remove file-to-remove tda/rsync-multiple-file-list))
	;; message for the use
	(message
	 (concat "File " (dired-get-filename 'verbatim) " removed from the list."))))

;; Copy file from multiple directories
(defun tda/rsync-multiple ()
  "Mark file in multiple places and then paste in 1 directory."
  (interactive)

  (let (command)
	(if (equal tda/rsync-multiple-file-list ())
		(progn
		  (message "Please add file to the waiting list."))
	  (progn
		;; the rsync command
		(setq command (concat tda/rsync-command-name " " tda/rsync-arguments " "))
		;; add all selected file names as arguments to the rsync command
		(dolist (file tda/rsync-multiple-file-list)
		  (setq command
				(concat command (shell-quote-argument file) " ")))
		;; append the destination to the rsync command
		(setq command
			  (concat command
                                  (cpb/maybe-convert-directory-to-rsync-target default-directory)))
		;; execute the command asynchronously
		(tat/execute-async command "rsync")
		;; empty the waiting list
		(tda/rsync-multiple-empty-list)))))

;; ----------------------------------------------
;; ----------------------------------------------
;; download file to current dir
(defvar tda/download-command "wget"
  "The download program to download to current dir.

The default is wget, ou can replace it to curl, aria2c, or others.")

(defun tda/download-to-current-dir (src)
  "Read the link and download the file to current directory/"
  (interactive (list (read-from-minibuffer "Link: ")))
  (let ((command ""))
	;; create the command
	(setq command (concat command tda/download-command " "))
	;; append the link
	(setq command (concat command (shell-quote-argument src)))
	;; execute
	(tat/execute-async command "download")))
(defun tda/download-clipboard-link-to-current-dir ()
  "Read the clipboard link and download it into the current dir."
  (interactive)
  (tda/download-to-current-dir (x-get-clipboard)))

(provide 'tmtxt-dired-async)
;;; tmtxt-dired-async.el ends here
