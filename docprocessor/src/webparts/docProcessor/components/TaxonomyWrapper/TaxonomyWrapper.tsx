import { TaxonomyPicker } from "@pnp/spfx-controls-react/lib/TaxonomyPicker";
import * as React from "react";
import ITaxonomyWrapperProps from "./ITaxonomyWrapperProps";

export default class TaxonomyWrapper extends React.Component<
  ITaxonomyWrapperProps,
  {}
> {
  public render(): React.ReactElement<ITaxonomyWrapperProps> {
    return (
      <>
        {!this.props.loading && (
          <TaxonomyPicker
            allowMultipleSelections={this.props.allowMultipleSelections}
            termsetNameOrID={this.props.termsetNameOrID}
            panelTitle={"Select Term"}
            label={this.props.label}
            initialValues={this.props.values}
            context={this.props.context}
            onChange={this.props.onValueChanged}
            isTermSetSelectable={false}
          ></TaxonomyPicker>
        )}
        {this.props.loading && (
          <TaxonomyPicker
            allowMultipleSelections={this.props.allowMultipleSelections}
            termsetNameOrID={this.props.termsetNameOrID}
            panelTitle={"Select Term"}
            disabled={true}
            label={this.props.label}
            initialValues={this.props.values}
            context={this.props.context}
            onChange={this.props.onValueChanged}
            isTermSetSelectable={false}
          ></TaxonomyPicker>
        )}
      </>
    );
  }
}
