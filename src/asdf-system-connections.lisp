(defpackage #:alternate-asdf-system-connections
  (:use #:cl #:asdf)
  (:export #:define-system-connection
           #:system-connection
           #:load-connected-systems))

(in-package #:alternate-asdf-system-connections)

;;; ---------------------------------------------------------------------------
;;; not particularly rich person's system interconnection facility
;;; ---------------------------------------------------------------------------

(defclass system-connection (system)
  ((systems-required :initarg :systems-required :reader systems-required)))

(define-condition dependency-feature-unsatisfied (condition)
  ((dependency :initarg :dependency)
   (feature :initarg :feature))
  (:report (lambda (condition stream)
             (with-slots (dependency feature) condition
               (format stream "Feature expression~%  ~S~%unsatisfied for system~%  ~S"
                       feature dependency)))))

(define-condition system-not-found (condition)
  ((system :initarg :system))
  (:report (lambda (condition stream)
             (with-slots (system) condition
               (format stream "Unable to find system ~A" system)))))

;; From alexandria
(defun featurep (feature-expression)
  "Returns T if the argument matches the state of the *FEATURES*
list and NIL if it does not. FEATURE-EXPRESSION can be any atom
or list acceptable to the reader macros #+ and #-."
  (etypecase feature-expression
    (symbol (not (null (member feature-expression *features*))))
    (cons
     (let ((first-expr (first feature-expression)))
       (check-type first-expr symbol)
       (cond ((string= :and first-expr)
              (every #'featurep (rest feature-expression)))
             ((string= :or first-expr)
              (some #'featurep (rest feature-expression)))
             ((string= :not first-expr)
              (assert (= 2 (length feature-expression)))
              (not (featurep (second feature-expression))))
             (t
              (error "Malformed feature expression: ~S"
                     feature-expression)))))))

;;; ---------------------------------------------------------------------------

(defun find-system-from-dep-spec (depends-on)
  (etypecase depends-on
    (system
     depends-on)
    ((or string symbol)
     (or (find-system depends-on nil)
         (error 'system-not-found :system depends-on)))
    (list
     (find-system
      (let ((spec (ecase (first depends-on)
                    (:version (second depends-on))
                    (:feature
                     (if (featurep (second depends-on))
                         (third depends-on)
                         (error 'dependency-feature-unsatisfied
                                :dependency (third depends-on)
                                :feature (second depends-on)))))))
        (etypecase spec
          ((or string symbol) spec)
          (list
           (ecase (first spec)
             (:require (second spec))))))
      nil))))

(defun system-depends-on-p (system depends-on)
  "Returns non-NIL if DEPENDS-ON is a dependency of SYSTEM."
  (let* ((system (handler-case (find-system-from-dep-spec system)
                   (system-not-found ()
                     (return-from system-depends-on-p nil))))
         (depends-on (find-system-from-dep-spec depends-on))
         (depends-on-name (when depends-on
                            (component-name depends-on))))
    (when (and system depends-on)
      (some (lambda (dep)
              (handler-case
                  (let* ((dep (find-system-from-dep-spec dep))
                         (dep-name (component-name dep)))
                    (or (string= dep-name depends-on-name)
                        (loop :for dep-dep :in (system-depends-on dep)
                                :thereis (system-depends-on-p dep-dep
                                                              depends-on))))
                (dependency-feature-unsatisfied () nil)
                (system-not-found () nil)))
            (system-depends-on system)))))

;;; ---------------------------------------------------------------------------

(defvar *system-connections* (make-hash-table :test 'equal))

(defmacro define-system-connection (name &body options)
  (let ((requires (getf options :requires))
        (depends-on (getf options :depends-on))
        (class (getf options :class 'system-connection))
        (connections (gensym "CONNECTIONS"))
        (prerequisites (gensym "PREREQUISITES")))
    (remf options :requires)
    (remf options :class)
    `(progn
       (defsystem ,name
         :class ,class
         :depends-on ,(append requires
                              depends-on)
         :systems-required ,requires
         ,@options)
       ,@(mapcar (lambda (r)
                   (flet ((system-name (s)
                            (etypecase s
                              (string s)
                              (symbol (string-downcase (symbol-name s)))
                              (asdf:component (asdf:component-name s)))))
                     (let* ((r    (system-name r))
                            (req  (gensym "REQ"))
                            (name (system-name name))
                            (requires
                              (sort (mapcar #'system-name requires) #'string<)))
                       `(let* ((,prerequisites
                                 (remove ',r ',requires
                                         :test #'string=))
                               (,connections
                                 (append (gethash ',r *system-connections*)
                                         (list (cons ,prerequisites
                                                     ',name)))))
                          (setf (gethash ',r *system-connections*)
                                ,connections)))))
                 requires)
       (values ',name))))

;;; ---------------------------------------------------------------------------

(defun load-connected-systems (operation component)
  (handler-case
      (let* ((component (find-system-from-dep-spec component))
             (deps (system-depends-on component))
             (connections (gethash (component-name component)
                                   *system-connections*)))
        ;; Load connections of dependencies of this system
        (loop :for dep :in deps
              :do (load-connected-systems 'asdf:load-op dep))
        (loop :for (prerequisites . connection) :in connections
              :do (when (and (not (component-loaded-p connection))
                             (every #'component-loaded-p prerequisites))
                    (dolist (prereq prerequisites)
                      (unless (system-depends-on-p prereq component)
                        ;; Do not recurse if PREREQ depends on COMPONENT
                        (dolist (dep (system-depends-on (find-system prereq)))
                          ;; Load connections of dependencies of other prerequisites
                          (load-connected-systems operation dep))))
                    ;; Load connection
                    (asdf:oos operation connection))))
    (dependency-feature-unsatisfied () nil)))

;;; ---------------------------------------------------------------------------

(defmethod operate :after ((operation t) (component t) &key &allow-other-keys)
  ;; Call for the system connections defined by DEFINE-SYSTEM-CONNECTION
  (when (or (eq 'asdf:load-op operation)
            (typep operation 'asdf:load-op))
    (load-connected-systems 'asdf:load-op component))
  ;; Call for the system connections defined by DEFSYSTEM-CONNECTION
  (asdf::load-connected-systems))

;;; ---------------------------------------------------------------------------

(eval-when (:compile-toplevel :load-toplevel :execute)
  (pushnew :alternate-asdf-system-connections cl:*features*)
  (import 'define-system-connection :asdf)
  (export 'define-system-connection :asdf))
