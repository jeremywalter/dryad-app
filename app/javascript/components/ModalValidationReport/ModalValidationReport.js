import React from 'react';

import classes from './ModalValidationReport.module.css';

import '@cdl-dryad/frictionless-components/lib/styles';
import {render} from '@cdl-dryad/frictionless-components/lib/render';
import {Report} from '@cdl-dryad/frictionless-components/lib/components/Report';


class ModalValidationReport extends React.Component {
    componentDidMount() {
        const element = document.getElementById('validation_report');
        render(Report, JSON.parse(this.props.file.frictionless_report.report), element);
    }

    render () {
        return (
            <div>
                <dialog className="c-uploadmodal"
                        style={{
                            'width': '60%', 'max-width': '950px', 'min-width': '220px',
                            'zIndex': '100149', 'top': '50%'}}
                        open>
                    <div className="c-uploadmodal__header">
                        <h2 className="c-datasets-heading__heading o-heading__level1">Formatting Report: {this.props.file.sanitized_name}</h2>
                        <button className={classes.CloseButton}
                                aria-label="close"
                                type="button"
                                onClick={(event) => this.props.clickedClose(event)} />
                    </div>
                    <div>
                      This report has been generated by our tabular data checker. Although you are not obligated to do so,
                      we recommend resolving the following formatting issues and re-uploading the file.
                    </div>
                    <ol>
                      <li>
                        Manually correct the issues shown here in your local copy of the file.
                      </li>
                      <li>Close this dialog and remove the file from the list with the <em>Remove</em> action.</li>
                      <li>Re-upload the corrected file using the <em>Choose Files</em> or <em>Enter URLs</em> button.</li>
                    </ol>
                    <div id="validation_report">
                    </div>
                </dialog>
                <div className="backdrop" style={{'zIndex': '100148'}} />
            </div>
        )
    }
}

export default ModalValidationReport;