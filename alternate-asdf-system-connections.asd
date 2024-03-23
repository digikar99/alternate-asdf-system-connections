;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-USER; Base: 10 -*-

(defsystem alternate-asdf-system-connections
  :version "0.9.0"
  :author "Gary Warren King <gwking@metabang.com>"
  :maintainer "Shubhamkar Ayare <shubhamayare@yahoo.co.in>"
  :licence "MIT"
  :depends-on ("asdf-system-connections")
  :description "Allows for ASDF system to be connected so that auto-loading may occur. This is a fork of asdf-system-connections and incorporates a load-system-driven mechanism for loading dependencies and also loads the dependencies of the connections."
  :components
  ((:module
    "src"
    :components ((:file "asdf-system-connections")))))
