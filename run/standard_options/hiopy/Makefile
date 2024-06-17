SOURCES = $(filter-out variables.yaml,$(wildcard *.yaml))
TARGETS = $(SOURCES:.yaml=.html)

all: $(TARGETS)

clean:
	$(RM) $(TARGETS)

%.html: %.yaml
	icon_variables render $< $@
