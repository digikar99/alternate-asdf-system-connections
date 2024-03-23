### alternate-asdf-system-connections

alternate-asdf-system-connections is a fork of [asdf-system-connections](https://github.com/lisp-maintainers/asdf-system-connections) that incorporates load-system-driven mechanism for loading dependencies and also loads the dependencies of the connections.

The essence of both asdf-system-connections and alternate-asdf-system-connections is to define a helper system to bridge two or more underlying systems.

Here is a simple example from [metabang-bind][]'s system
definition:

    (asdf:defsystem-connection bind-and-metatilities
           :requires (metabang-bind metatilities-base)
           :perform (load-op :after (op c)
                             (use-package (find-package :metabang-bind)
                                          (find-package :metatilities))))

The _requires_ clause specifies the other systems that must
be loaded before this connection will be activated. The rest
of the system definition is regular [ASDF][].
alternate-asdf-system-connections will be loaded as soon as the systems
they require are all loaded and they will only be loaded
once. Before loading a system that uses a system connection,
you should load ASDF-System-Connections in the usual manner:

    (asdf:oos 'asdf:load-op 'alternate-asdf-system-connections)

### What is happening

<dl>
<dt>17 March 2024</dt>
<dd>A fork alternate-asdf-system-connections is created that autoloads the dependencies of the connections in an appropriate order.</dd>
<dt>24 February 2013</dt>
<dd>Updates to make ASC happ(ier) with ASDF; website tweaks</dd>

<dt>19 October 2008</dt>
<dd>Website rework -- no fire, just smoke</dd>
    </dl>
</div>
</div>

