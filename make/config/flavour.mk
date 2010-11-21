# Setting 
include make/config.mk
include make/config/options.mk

BuildFlavour    := $(strip $(BUILDFLAVOUR))

# -- Distribution compile (fastest at runtime)
ifeq "$(BuildFlavour)" "distro"
GHC_FLAGS	:= $(GHC_WARNINGS) $(GHC_LANGUAGE) -rtsopts -O2
GCC_FLAGS	:= -std=c99 -O3 -Wundef

# -- Development Compile (fastest compile)
else ifeq "$(BuildFlavour)" "devel"
GHC_FLAGS	:= $(GHC_WARNINGS) $(GHC_LANGUAGE) -rtsopts -O0
GCC_FLAGS	:= -std=c99 -O3 -Wall -Wextra

# -- Debug compile
else ifeq "$(BuildFlavour)" "devel_debug"
GHC_FLAGS	:= $(GHC_WARNINGS) $(GHC_LANGUAGE) -rtsopts -O0
GCC_FLAGS	:= -std=c99 -Wundef -g

# -- Profiling compile
else ifeq "$(BuildFlavour)" "devel_prof"
GHC_FLAGS	:= $(GHC_WARNINGS) $(GHC_LANGUAGE) -rtsopts -O2 -prof -auto-all
GCC_FLAGS	:= -std=c99 -Wundef -g -pg

# -- For Haskell Program Coverage
else ifeq "$(BuildFlavour)" "devel_hpc"
GHC_FLAGS	:= $(GHC_WARNINGS) $(GHC_LANGUAGE) -rtsopts -fhpc
GCC_FLAGS	:= -std=c99 -O3 -Wundef

else 
all : $(error "Unknown BuildFlavour '$(BuildFlavour)'. Set this in make/config.mk")
endif
