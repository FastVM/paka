define TO_BOOL_IMPL
TO_BOOL_IMPL_RESULT:=UNDEFINED
ifeq ($1,)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,1)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,0)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,true)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,false)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,t)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,f)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,TRUE)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,FALSE)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,T)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,F)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,yes)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,no)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,YES)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,NO)
TO_BOOL_IMPL_RESULT:=FALSE
endif
ifeq ($1,y)
TO_BOOL_IMPL_RESULT:=TRUE
endif
ifeq ($1,n)
TO_BOOL_IMPL_RESULT:=FALSE
endif
endef

define TO_BOOL_IMPL_FAIL_IF_UNDEF
ifeq ($(TO_BOOL_IMPL_RESULT),UNDEFINED)
$(error $1 has no yes/no value)
endif
endef

tobool=$(eval $(TO_BOOL_IMPL))$(TO_BOOL_IMPL_RESULT)