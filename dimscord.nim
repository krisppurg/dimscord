import lib/[gateway, restapi, constants, objects, cacher, misc], options

export gateway, restapi, constants, objects, cacher, misc

proc `?`*[T](o: T): Option[T] =
    result = option(o)
